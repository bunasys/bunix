#!/usr/bin/env python3
"""Boot bunix in QEMU, headless, and run checks on the booted system.

usage: tools/boot-test.py <live.img|disk.raw|old.iso> <uefi|bios> <outdir>


The file's extension says how it is attached:
  .img  the live image (system/live.bst), as a read-only USB stick
  .raw  an installed disk (system/disk.bst, or one bunix-install wrote) --
        disk images are always .raw
  .iso  a live ISO of 0.2.2 or before, as a CD -- for the update test,
        which installs the previous release; BOOT_USB=1 attaches it as a
        USB stick instead

A .raw disk image (system/disk.bst) is booted from a working copy,
<outdir>/disk.raw, grown to 8 GB so its first boot has room for the root
partition.  The copy is kept: running again with the same <outdir> boots the
same disk again, as a reboot would.  Under UEFI the firmware's variables
(boot entries) are kept in <outdir> as well, for live and disk runs alike.

BOOT_DISK=<file> attaches a disk image to a live run (bunix-install's
target): create <outdir>/disk.raw, install to it from the live system, then
boot it with a disk run of the same <outdir>.

Boots the default boot entry, waits for boot to finish, then types each
check on the VM's keyboard -- the screen console (tty1) runs root's fish on
the live system and on a disk whose root has no password -- with the output
redirected to the serial port, which this script reads.  Writes serial.log
(the checks' output) and screenshots as PNG to <outdir>: every 3 s for the
first 15 s (the boot splash), after boot, after BOOT_KEYS, at the end.
Exits non-zero if a check did not finish.

BOOT_KEYS=<text> is typed on the screen after boot, before the checks: a
password at a desktop install's login screen, say.  "\\n" is Enter,
"<meta_l-ret>" a QEMU key name (lower case), "<sleep_10>" a pause.  The
screenshot follows BOOT_KEYS_WAIT seconds later (default 20).

BOOT_MEMORY sets the VM's memory (default 1G), BOOT_NIC its network card
(default e1000e).  BOOT_SHELL=bash types the checks for bash (an
initrd's emergency shell) instead of root's fish.  BOOT_CHECKS=<file> replaces the checks below with the file's lines (one
command line each; empty lines and lines starting with # are skipped); an
empty file (/dev/null) means no checks, only the screenshots.

Uses KVM when /dev/kvm is usable.  OVMF is looked up in the usual places;
set OVMF_CODE to point elsewhere.
"""
import os, re, shutil, socket, struct, subprocess, sys, tempfile, time, zlib

CHECKS = [
    "systemctl is-system-running; systemctl --failed --no-legend --no-pager",
    "uname -r; cat /etc/os-release; readlink /bin/sh; grep root /etc/passwd",
    "networkctl --no-pager",
    "resolvectl status --no-pager | grep -E 'Current DNS|resolv.conf'",
    "curl -sS -o /dev/null -w 'HTTP %{http_code} via %{remote_ip}\n' https://example.com",
    "dig +short example.com A | head -2; host kernel.org | head -1",
    "ls --version | head -1; find --version | head -1; rg --version | head -1",
    "nvim --version | head -1; readlink /usr/bin/vi; less --version | head -1",
    "ps --version; pstree -V 2>&1 | head -1; htop --version; free --version",
    "lsblk --version; ifconfig --version 2>&1 | head -1; netstat -V 2>&1 | head -1",
    "iwctl --help | head -1; systemctl is-active iwd dbus systemd-resolved systemd-networkd systemd-timesyncd",
    "systemd-analyze --no-pager; free -m | head -2",
]
OVMF_CANDIDATES = [
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd",            # Arch
    "/usr/share/OVMF/OVMF_CODE_4M.fd",                 # Debian, Ubuntu
    "/usr/share/edk2/ovmf/OVMF_CODE.fd",               # Fedora
    "/opt/homebrew/share/qemu/edk2-x86_64-code.fd",    # Homebrew
]

image, firmware, outdir = sys.argv[1], sys.argv[2], sys.argv[3]
is_live_image = image.endswith(".img")
boots_disk = image.endswith(".raw")
is_old_iso = image.endswith(".iso")
if not (is_live_image or boots_disk or is_old_iso):
    sys.exit(f"{image}: expected a .img, .raw or .iso file")
wants_usb = bool(os.environ.get("BOOT_USB"))
if wants_usb and not is_old_iso:
    sys.exit("BOOT_USB is for an old .iso; a .img is a USB stick already")
boots_usb = is_live_image or wants_usb
if os.environ.get("BOOT_CHECKS"):
    lines = open(os.environ["BOOT_CHECKS"]).read().splitlines()
    CHECKS = [line for line in lines if line.strip() and not line.startswith("#")]
os.makedirs(outdir, exist_ok=True)

# unix socket paths are limited to ~104 bytes, so they live in a short dir
sockdir = tempfile.mkdtemp(prefix="bt", dir="/tmp")
monitor_path = os.path.join(sockdir, "monitor")
serial_path = os.path.join(sockdir, "serial")

qemu_args = ["qemu-system-x86_64", "-machine", "q35", "-smp", "2", "-m", os.environ.get("BOOT_MEMORY", "1G"),
             "-nic", "user,model=" + os.environ.get("BOOT_NIC", "e1000e"),
             "-display", "none", "-vga", "std",
             "-monitor", f"unix:{monitor_path},server,nowait",
             "-serial", f"unix:{serial_path},server,nowait"]
if boots_disk:
    disk = os.path.join(outdir, "disk.raw")
    if not os.path.exists(disk):
        subprocess.run(["cp", "--sparse=always", image, disk], check=True)
        os.truncate(disk, 8 * 1024**3)
    qemu_args += ["-drive", f"if=virtio,format=raw,file={disk}"]
elif boots_usb:
    qemu_args += ["-device", "qemu-xhci",
                  "-drive", f"if=none,id=stick,format=raw,readonly=on,file={image}",
                  "-device", "usb-storage,drive=stick,bootindex=0"]
else:
    qemu_args += ["-cdrom", image, "-boot", "d"]
if os.environ.get("BOOT_DISK") and not boots_disk:
    qemu_args += ["-drive", f"if=virtio,format=raw,file={os.environ['BOOT_DISK']}"]
if os.access("/dev/kvm", os.R_OK | os.W_OK):
    qemu_args += ["-accel", "kvm", "-cpu", "host"]
else:
    qemu_args += ["-cpu", "max"]
if firmware == "uefi":
    candidates = [os.environ.get("OVMF_CODE", "")] + OVMF_CANDIDATES
    ovmf = next(path for path in candidates if path and os.path.exists(path))
    qemu_args += ["-drive", f"if=pflash,format=raw,readonly=on,file={ovmf}"]
    # the firmware's variables, kept with the disk: boot entries (shim's
    # fallback's, bunix-install's) outlive the run
    vars_copy = os.path.join(outdir, "ovmf-vars.fd")
    if not os.path.exists(vars_copy):
        shutil.copyfile(ovmf.replace("CODE", "VARS"), vars_copy)
    qemu_args += ["-drive", f"if=pflash,format=raw,file={vars_copy}"]
qemu = subprocess.Popen(qemu_args, stdout=open(os.path.join(outdir, "qemu.out"), "w"),
                        stderr=subprocess.STDOUT)


def connect(path):
    for _ in range(100):
        try:
            s = socket.socket(socket.AF_UNIX)
            s.connect(path)
            return s
        except OSError:
            time.sleep(0.1)
    raise SystemExit(f"cannot connect to {path}")


monitor = connect(monitor_path)
serial = connect(serial_path)
serial.setblocking(False)
serial_log = open(os.path.join(outdir, "serial.log"), "wb")
serial_seen = b""


def read_serial(seconds):
    global serial_seen
    end = time.time() + seconds
    while time.time() < end:
        try:
            data = serial.recv(65536)
            if data:
                serial_seen += data
                serial_log.write(data)
                serial_log.flush()
                continue
        except BlockingIOError:
            pass
        time.sleep(0.05)


def wait_for_serial(token, timeout):
    end = time.time() + timeout
    while time.time() < end:
        if token.encode() in serial_seen:
            return True
        read_serial(0.5)
    return False


def monitor_command(command):
    monitor.sendall((command + "\n").encode())
    time.sleep(0.3)
    discard_monitor_output()


def type_keys(text):
    """BOOT_KEYS: text, with "<name>" for QEMU's key names (<meta_l-ret> is
    Super+Return) and "<sleep_N>" for a pause of N seconds, for what the keys
    before it started."""
    for token in re.findall(r"<[a-z0-9_-]+>|[^<]+|<", text):
        sleep = re.fullmatch(r"<sleep_(\d+)>", token)
        is_key_name = re.fullmatch(r"<[a-z0-9_-]+>", token)
        if sleep:
            time.sleep(int(sleep[1]))
        elif is_key_name:
            monitor.sendall(f"sendkey {token[1:-1]}\n".encode())
            time.sleep(0.04)
        else:
            type_on_screen(token)


def discard_monitor_output():
    monitor.setblocking(False)
    try:
        while monitor.recv(65536):
            pass
    except BlockingIOError:
        pass
    monitor.setblocking(True)


# QEMU key names for a US keyboard layout
SHIFTED = {"!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7",
           "*": "8", "(": "9", ")": "0", "_": "minus", "+": "equal",
           "{": "bracket_left", "}": "bracket_right", "|": "backslash",
           ":": "semicolon", '"': "apostrophe", "<": "comma", ">": "dot",
           "?": "slash", "~": "grave_accent"}
PLAIN = {" ": "spc", "-": "minus", "=": "equal", "[": "bracket_left",
         "]": "bracket_right", "\\": "backslash", ";": "semicolon",
         "'": "apostrophe", "`": "grave_accent", ",": "comma", ".": "dot",
         "/": "slash", "\n": "ret"}


def type_on_screen(text):
    for ch in text:
        if ch.isalpha() and ch.isupper():
            key = "shift-" + ch.lower()
        elif ch.isalnum():
            key = ch
        elif ch in SHIFTED:
            key = "shift-" + SHIFTED[ch]
        else:
            key = PLAIN[ch]
        monitor.sendall(f"sendkey {key}\n".encode())
        time.sleep(0.04)
    time.sleep(0.3)
    discard_monitor_output()


def ppm_to_png(ppm, png):
    data = open(ppm, "rb").read()
    parts = data.split(b"\n", 3)
    width, height = map(int, parts[1].split())
    pixels = parts[3]
    row = width * 3
    raw = b"".join(b"\x00" + pixels[y * row:(y + 1) * row] for y in range(height))

    def chunk(kind, body):
        crc = zlib.crc32(kind + body) & 0xffffffff
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", crc)

    header = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    open(png, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
                          + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def screenshot(name):
    ppm = os.path.join(outdir, name + ".ppm")
    monitor_command(f"screendump {ppm}")
    time.sleep(0.5)
    if os.path.exists(ppm):
        ppm_to_png(ppm, os.path.join(outdir, name + ".png"))
        os.unlink(ppm)


start = time.time()
# the boot splash: a picture every 3 seconds while the machine starts
for second in (3, 6, 9, 12, 15):
    time.sleep(3)
    screenshot(f"1-boot-{second:02}s")
read_serial(int(os.environ.get("BOOT_WAIT", "60")))
screenshot("2-after-boot")
if os.environ.get("BOOT_KEYS"):
    # typed on whatever the screen shows, a login screen's password field say
    type_keys(os.environ["BOOT_KEYS"].replace("\\n", "\n"))
    read_serial(int(os.environ.get("BOOT_KEYS_WAIT", "20")))
    screenshot("2-after-keys")
# Without checks the screen may be a login screen: "clear" would go into
# its password field
if CHECKS:
    type_on_screen("clear\n")

unfinished = 0
for i, check in enumerate(CHECKS):
    marker = f"__done_{i}__"
    # The typed line contains __done_""N__; only the shell's output joins it
    # into the marker, so the echo of the typed command cannot match.
    if os.environ.get("BOOT_SHELL") == "bash":
        typed = f"{{ {check}; }} >/dev/ttyS0 2>&1; echo __done_\"\"{i}__ >/dev/ttyS0\n"
    else:
        typed = f"begin; {check}; end >/dev/ttyS0 2>&1; echo __done_\"\"{i}__ >/dev/ttyS0\n"
    type_on_screen(typed)
    if not wait_for_serial(marker, 90):
        print(f"check {i} did not finish: {check}")
        unfinished += 1
    read_serial(1)

screenshot("3-end")
print(f"{len(CHECKS) - unfinished}/{len(CHECKS)} checks finished after {time.time() - start:.0f}s")
monitor_command("quit")
qemu.wait(timeout=20)
serial_log.close()
shutil.rmtree(sockdir, ignore_errors=True)
sys.exit(1 if unfinished else 0)

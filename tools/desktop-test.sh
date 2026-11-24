#!/bin/sh
# Tests the desktop extension (nix/images/desktop.nix) on a test system
# in a virtual machine, from an Apple Silicon Mac:
#
#   tools/desktop-test.sh
#
# The machine is a test system's disk, as tools/boot-vm.sh starts one,
# with a screen.  Then:
#
#   1. the extension, signed with the development key, is put where an
#      update puts it, and systemd-sysext merges it; the unit it brings
#      (the font cache) starts
#   2. niri starts on the machine's screen, through seatd, as root at the
#      console would start it: it finds the screen, and its keyboard
#   3. niri takes a picture of its screen, which it draws with OpenGL
#      through Mesa: the picture is copied here, to be looked at
#
# What is not tested: a GPU's own driver.  The x86_64 machine's GPU is
# QEMU's standard VGA, and the arm64 one's virtio's, 2D only (QEMU on a
# Mac): Mesa draws with llvmpipe on both, which niri is told to take.  Nor what a person sees: the picture is the
# screen as niri drew it, which only a look at it says is right.
#
#   BUNIX_ARCHITECTURE, BUNIX_X86_BUILDER
#                      tools/test-machine.sh
#   BUNIX_SSH_KEY      the public key the test logs in with; default
#                      ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT     the port for the machine's SSH; default 2022
#
# Needs: what tools/boot-vm.sh needs.
set -eu

public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "desktop-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi
ssh_port=${BUNIX_SSH_PORT:-2022}
# A machine that is not this test's, on the port, would answer for it.
if nc -z 127.0.0.1 "$ssh_port" 2> /dev/null; then
    echo "desktop-test.sh: port $ssh_port is taken; end what has it, or set BUNIX_SSH_PORT" >&2
    exit 1
fi
tool=desktop-test.sh
. "$(dirname "$0")/test-machine.sh"

fail() {
    echo "desktop-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}
prepare_machine
version=$(release_version)

echo "building a test system's disk, and its desktop extension"
disk=$(build "$source/nix/images/disk.nix" --argstr espSize 512M \
    --argstr usrSlotSize 512M --argstr usrVeritySize 8M)
desktop=$(build "$source/nix/images/desktop.nix" -A image)
copy_built_file_to_machine "$disk/disk.raw" disk.raw
in_machine_directory "truncate -s +2G disk.raw"
copy_built_file "$desktop/desktop_*.raw" "$work/desktop.raw"

# The key that may log in, as boot-vm.sh gives it: a credential on the
# kernel's command line, which the firmware hands over (SMBIOS).
key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
smbios_words=$(printf 'console=%s %s' "$console" "$key_word" | sed 's/,/,,/g')
# shellcheck disable=SC2086
start_qemu $machine_on_real_processor $efi_firmware \
    -drive "file=$machine_directory/disk.raw,format=raw,if=virtio" \
    -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
trap 'kill $qemu 2> /dev/null || true' EXIT

in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
deadline=$(($(date +%s) + 120))
until in_guest true 2> /dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ] || ! kill -0 "$qemu" 2> /dev/null; then
        fail "the machine did not answer on SSH"
    fi
    sleep 2
done
in_guest systemctl is-system-running --wait > /dev/null 2>&1 || true

echo "1. the desktop extension is merged"
# where an update puts a version's extensions (sysupdate.d/), read-only
# as it leaves them
extension=/var/lib/bunix/extensions/desktop_$version.raw
in_guest "mkdir -p /var/lib/bunix/extensions && cat > $extension && chmod 0444 $extension" \
    < "$work/desktop.raw" || fail "could not put the extension on the machine"
in_guest "systemctl restart systemd-sysext.service" \
    || fail "systemd-sysext did not merge the extensions; see: journalctl -u systemd-sysext"
in_guest "systemd-sysext status" > "$work/sysext.log" 2>&1 || true
grep -q desktop "$work/sysext.log" || fail "the desktop extension is not merged; see $work/sysext.log"
in_guest "command -v niri" > /dev/null || fail "merged, but niri is not there"
# Upheld by multi-user.target, which systemd starts as soon as it knows
# the unit: after the merge, which has it read its units again.
in_guest "timeout 60 sh -c 'until systemctl is-active -q fontconfig-cache.service; do sleep 1; done'" \
    || fail "the font cache's unit did not start"
echo "  merged; niri is there, and the font cache's unit ran"

echo "2. niri starts on the screen"
# As root would start it at the console: seatd-launch runs seatd, which
# gives niri the screen and the input devices, and ends with it.  A unit
# of its own, so that it runs on when this login ends; its log is
# systemd's.
# BUNIX_NIRI_SOFTWARE_RENDERING: niri draws with llvmpipe, which it
# refuses otherwise (files/niri/), since these machines have no GPU that
# draws.
in_guest "systemd-run --unit=desktop-test-niri --setenv=XDG_RUNTIME_DIR=/run/desktop-test \
    --setenv=BUNIX_NIRI_SOFTWARE_RENDERING=1 \
    --property=RuntimeDirectory=desktop-test seatd-launch -- niri" > /dev/null \
    || fail "could not start niri"
# niri says where it listens (NIRI_SOCKET) once it has its screens
socket=
deadline=$(($(date +%s) + 60))
while [ -z "$socket" ]; do
    socket=$(in_guest "ls /run/desktop-test/niri.*.sock 2> /dev/null" || true)
    if [ "$(date +%s)" -ge "$deadline" ]; then
        in_guest "journalctl -u desktop-test-niri --no-pager" > "$work/niri.log" 2>&1 || true
        fail "niri did not start; its log is in $work/niri.log"
    fi
    sleep 2
done
niri_msg="NIRI_SOCKET=$socket niri msg"
# What niri said, and what screens the kernel has, for a failure from
# here on
fail_with_niri_log() {
    in_guest "journalctl -u desktop-test-niri --no-pager; ls -l /dev/dri; cat /sys/class/drm/*/status" \
        > "$work/niri.log" 2>&1 || true
    fail "$* (niri's log, and the kernel's screens: $work/niri.log)"
}
in_guest "$niri_msg outputs" > "$work/outputs.log" 2>&1 \
    || fail_with_niri_log "niri does not answer; see $work/outputs.log"
grep -q "^Output" "$work/outputs.log" || fail_with_niri_log "niri has no screen"
sed -n 's/^Output /  screen: /p' "$work/outputs.log"

echo "3. niri draws, and takes a picture of what it drew"
in_guest "$niri_msg action screenshot-screen --path /run/desktop-test/screen.png" \
    > /dev/null || fail_with_niri_log "niri did not take a picture of its screen"
in_guest "timeout 10 sh -c 'until [ -s /run/desktop-test/screen.png ]; do sleep 1; done'
    cat /run/desktop-test/screen.png" > "$work/screen.png" \
    || fail_with_niri_log "niri wrote no picture of its screen"
# a PNG file starts with these eight bytes
[ "$(head -c 8 "$work/screen.png" | od -An -tx1 | tr -d ' \n')" = 89504e470d0a1a0a ] \
    || fail "what niri wrote is not a picture"
in_guest "journalctl -u desktop-test-niri --no-pager" > "$work/niri.log" 2>&1 || true
# what drew it: the renderer that Mesa gave niri, in niri's log
renderer=$(grep -o -i "renderer: [^,]*" "$work/niri.log" | head -n 1 || true)
echo "  $renderer"
echo "  the picture: $work/screen.png"

in_guest systemctl poweroff || true
wait "$qemu" || true
echo "desktop-test.sh: passed"

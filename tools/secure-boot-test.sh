#!/bin/sh
# Tests that a PC with Secure Boot on starts bunix, and refuses a kernel
# image that is not as it was signed, in a virtual machine on the x86_64
# builder (tools/test-machine.sh), from an Apple Silicon Mac:
#
#   tools/secure-boot-test.sh
#
# The disk is a test system's (nix/images/disk.nix, secureBootEnrolment):
# its kernel image and systemd-boot are signed with the development key,
# and the firmware, which has no keys of its own yet, is given that one.
# The firmware is QEMU's with Secure Boot (edk2-x86_64-secure-code.fd).
# Then:
#
#   1. the first start: systemd-boot gives the firmware the key, and the
#      machine restarts
#   2. it starts with Secure Boot on, and says so
#   3. a few bytes of its kernel image are changed, on its own disk: the
#      firmware refuses the image, and the machine does not start
#
# Then as a PC with Microsoft's keys starts bunix, through shim:
#
#   4. a firmware with no keys again starts the live stick
#      (nix/images/live.nix, of a test system): shim, signed by
#      Microsoft, which starts systemd-boot, which gives the firmware
#      Microsoft's UEFI CA and the development key, and the machine
#      restarts
#   5. the stick starts with Secure Boot on -- firmware, shim, systemd-boot,
#      the live kernel image, each checking the next -- and bunix-install
#      puts bunix on an empty disk: shim, and systemd-boot beside it
#   6. that disk starts with Secure Boot on, by the shim on it, and the
#      person the installer was told of logs in
#
# The kernel images and systemd-boot are signed by the script a
# release's are signed by (tools/sign-kernel-image.sh), with another
# key.  What is not tested here: a key enrolled with shim's MokManager
# (MOK), which is how a PC whose firmware has Microsoft's keys alone
# takes bunix's: its screen asks a person (here the key is in the
# firmware's db, which shim takes too).  A Mac has no Secure Boot.
#
#   BUNIX_X86_BUILDER  tools/test-machine.sh
#   BUNIX_SSH_KEY      the public key the test logs in with; default
#                      ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT     the port for the machine's SSH; default 2022
#
# Needs: what tools/boot-vm.sh needs for x86_64.
set -eu

public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "secure-boot-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi
ssh_port=${BUNIX_SSH_PORT:-2022}
# A machine that is not this test's, on the port, would answer for it.
if nc -z 127.0.0.1 "$ssh_port" 2> /dev/null; then
    echo "secure-boot-test.sh: port $ssh_port is taken; end what has it, or set BUNIX_SSH_PORT" >&2
    exit 1
fi
BUNIX_ARCHITECTURE=x86_64
tool=secure-boot-test.sh
. "$(dirname "$0")/test-machine.sh"

fail() {
    echo "secure-boot-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}
prepare_machine

echo "building a disk whose firmware is to be given the development key, and a live stick"
disk=$(build "$source/nix/images/disk.nix" --arg secureBootEnrolment true \
    --argstr espSize 256M --argstr usrSlotSize 512M --argstr usrVeritySize 16M)
copy_built_file_to_machine "$disk/disk.raw" disk.raw
in_machine_directory "truncate -s +2G disk.raw"
live=$(build "$source/nix/images/live.nix" -A image --arg secureBootEnrolment true)
copy_built_file_to_machine "$live/bunix-x86-64-live.img" live.img
# as large as a stick is, and a disk to install to: empty, and as large as
# it is only in name
in_machine_directory "truncate -s 16G live.img && rm -f installed.raw && truncate -s 16G installed.raw"
version=$(release_version)

# The firmware with Secure Boot, which it can keep only where nothing
# but the firmware writes its variables: in the processor's system
# management mode (smm=on, and a variables' store only that mode writes).
secure_firmware="-machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on
    -accel kvm -cpu host
    -drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/qemu/edk2-x86_64-secure-code.fd
    -drive if=pflash,format=raw,unit=1,file=$machine_directory/efi-variables.fd"

# The key that may log in, as a credential the machine's firmware hands
# over (SMBIOS), which systemd takes with or without Secure Boot; not on
# the kernel's command line, which a kernel image with Secure Boot keeps
# to its own.
key_credential="io.systemd.credential.binary:bunix.authorized_keys=$(base64 < "$public_key_file" | tr -d '\n')"
# Each start's own lines of the console are what follow those before it
# (start_qemu adds to one file): this start's begin after $console_seen.
#   start_with <QEMU's words for the disks>
start_with() {
    console_seen=0
    if [ -f "$work/console.log" ]; then
        console_seen=$(wc -c < "$work/console.log")
    fi
    # shellcheck disable=SC2086
    start_qemu $secure_firmware $1 -smbios "type=11,value=$key_credential"
}
start() {
    start_with "-drive file=$machine_directory/disk.raw,format=raw,if=virtio"
}
# The stick first (bootindex), and the disk bunix is installed to, as
# tools/install-test.sh has them; the disk alone, by what is on it.
installed_disk="-drive file=$machine_directory/installed.raw,format=raw,if=none,id=installed -device virtio-blk-pci,drive=installed,bootindex=1"
stick_and_disk="-device qemu-xhci -drive file=$machine_directory/live.img,format=raw,if=none,id=stick
    -device usb-storage,drive=stick,bootindex=0 $installed_disk"
trap 'kill $qemu 2> /dev/null || true' EXIT
# what this start has written to the console
this_start_said() {
    tail -c +$((console_seen + 1)) "$work/console.log" | grep -a -q -i "$1"
}

in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
# the person the installer was told of, on the installed system
as_tessa() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR -o BatchMode=yes tessa@127.0.0.1 "$@"
}
# answers_within <seconds> [the login's command]: does the machine take a
# login in that time?
answers_within() {
    deadline=$(($(date +%s) + $1))
    login=${2:-in_guest}
    until $login true 2> /dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ] || ! kill -0 "$qemu" 2> /dev/null; then
            return 1
        fi
        sleep 2
    done
}
# ends_within <seconds>: has QEMU ended in that time?  (It ends where a
# real machine would restart: run_qemu.)
ends_within() {
    deadline=$(($(date +%s) + $1))
    while kill -0 "$qemu" 2> /dev/null; do
        if [ "$(date +%s)" -ge "$deadline" ]; then
            return 1
        fi
        sleep 2
    done
    end_qemu
}

echo "1. the first start: the firmware is given the key"
start
ends_within 120 || fail "the machine did not restart after it was to be given the key"
this_start_said "keys successfully enrolled" \
    || fail "systemd-boot did not say it gave the firmware the key"
echo "  systemd-boot gave the firmware the key, and the machine restarted"

echo "2. bunix starts with Secure Boot on"
start
answers_within 120 || fail "the machine did not start with Secure Boot on"
# The firmware's own word for it: its variable SecureBoot (of the vendor
# EFI_GLOBAL_VARIABLE, the id below), a byte after four of attributes.
secure_boot=$(in_guest "od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c" | tr -d ' ')
[ "$secure_boot" = 1 ] || fail "the machine started, but Secure Boot is not on (SecureBoot: $secure_boot)"
echo "  started, and the firmware says Secure Boot is on"

echo "3. a kernel image changed after it was signed is refused"
# A few bytes in the middle of the image: what the signature covers is
# all of it but its own place and a checksum, and the image starts as
# before where nothing checks it.
in_guest 'set -e
    esp=$(bootctl --print-esp-path)
    image=$(ls $esp/EFI/Linux/bunix_*.efi)
    size=$(stat -c %s $image)
    printf "changed by a test" | dd of=$image bs=1 seek=$((size / 2)) conv=notrunc status=none
    sync' || fail "could not change the kernel image on the machine's disk"
in_guest systemctl poweroff || true
ends_within 60 || fail "the machine did not power off"
start
if answers_within 60; then
    fail "the machine started a kernel image that was changed after it was signed"
fi
kill -0 "$qemu" 2> /dev/null \
    || fail "the machine ended before its kernel image could be refused"
this_start_said "security violation\|access denied" \
    || fail "the machine did not start, but not because the firmware refused the image"
echo "  the firmware refused it"
end_qemu

# Whether the firmware says Secure Boot is on: its variable SecureBoot
#   secure_boot_is_on <the login's command>
secure_boot_is_on() {
    secure_boot=$($1 "od -An -tu1 -j4 -N1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c" | tr -d ' ')
    [ "$secure_boot" = 1 ]
}

echo "4. a firmware with no keys starts the live stick: shim, then systemd-boot gives it the keys"
# the firmware's variables as a new machine has them: none
in_machine_directory "cp $builder_store$qemu_package/usr/share/qemu/edk2-i386-vars.fd efi-variables.fd && chmod u+w efi-variables.fd"
start_with "$stick_and_disk"
ends_within 120 || fail "the machine did not restart after it was to be given the keys"
this_start_said "keys successfully enrolled" \
    || fail "systemd-boot, started by the stick's shim, did not say it gave the firmware the keys"
echo "  the stick's shim started systemd-boot, which gave the firmware the keys"

echo "5. the stick starts with Secure Boot on, and installs bunix"
start_with "$stick_and_disk"
answers_within 120 || fail "the live stick did not start with Secure Boot on"
secure_boot_is_on in_guest || fail "the live stick started, but Secure Boot is not on"
# the disk to install to: the one virtio disk (the stick is USB's)
installed=$(in_guest "lsblk -ndpo NAME,TYPE | awk '\$2 == \"disk\" && \$1 ~ /vd/ { print \$1 }'")
# The one disk it offers (the stick is not one), whole; the console;
# bash; the disk's name to go on
printf '%s\n' 1 1 2 tessas-pc "Tessa of the PC" tessa 1 "a password of Tessa's" "a password of Tessa's" "$installed" |
    in_guest "bunix-install /run/bunix/medium/install" > "$work/install.log" 2>&1 \
    || fail "the installer failed with Secure Boot on; see $work/install.log"
grep -q "Secure Boot is on" "$work/install.log" \
    || fail "the installer did not say what Secure Boot asks of a first start; see $work/install.log"
# The test's own way in: its key in Tessa's home, as tools/install-test.sh
# gives one
in_guest "mkdir -p /run/new-root && mount \$(lsblk -nrpo NAME,PARTLABEL $installed | sed -n 's| bunix-root\$||p') /run/new-root &&
    install -d -m 700 /run/new-root/home/tessa/.ssh && cat > /run/new-root/home/tessa/.ssh/authorized_keys &&
    chown -R --reference=/run/new-root/home/tessa /run/new-root/home/tessa/.ssh && umount /run/new-root" < "$public_key_file" \
    || fail "could not put the test's key in Tessa's home"
in_guest systemctl poweroff || true
ends_within 60 || fail "the live stick's system did not power off"
echo "  started, Secure Boot on, and bunix-install put bunix on the disk"

echo "6. the installed disk starts with Secure Boot on, by its shim"
start_with "$installed_disk"
answers_within 120 as_tessa || fail "the installed disk did not start with Secure Boot on"
secure_boot_is_on as_tessa || fail "the installed disk started, but Secure Boot is not on"
running=$(as_tessa "sed -n 's/^IMAGE_VERSION=//p' /usr/lib/os-release")
[ "$running" = "$version" ] || fail "bunix $running started, not $version"
echo "  bunix $running started with Secure Boot on, and Tessa logged in"
end_qemu

echo "secure-boot-test.sh: passed"

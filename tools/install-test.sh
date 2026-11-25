#!/bin/sh
# Tests bunix-install (nix/images/system/usr/bin/bunix-install) in a
# virtual machine, from an Apple Silicon Mac:
#
#   tools/install-test.sh
#   BUNIX_ARCHITECTURE=x86_64 tools/install-test.sh
#
# The machine is the Mac's own, or one on the x86_64 builder
# (tools/test-machine.sh): a PC, which is given the same two disks.  What
# only an Apple Silicon Mac has is then left out, and said below: what
# its boot loader loads from the ESP, and U-Boot.
#
# bunix is started in memory, as on a machine it is to be installed on,
# with two disks.  The Mac's machine is started as tools/boot-mac.sh
# starts a Mac, handed firmware of its own as a Mac is, and given the
# files of its version (nix/images/update.nix), with its desktop
# extension (nix/images/desktop.nix) as a release has it.  The PC starts
# from the live image (nix/images/live.nix), as a USB stick, which has
# the same files; the stick is not to be offered as a disk.  It installs
# twice:
#
#   1. onto a whole, empty disk, with the desktop; the machine's flash
#      chip is not to be offered as one
#   2. onto a disk laid out as a Mac's is, with sectors of 4096 bytes as
#      a Mac's has: Apple's partitions before and after, and between them
#      another system's ESP, an ESP for bunix, a root partition of an
#      earlier Linux, and free space (what mbp20's disk has, and an ESP
#      more).  The installer replaces the Linux partition, and is told
#      which ESP is bunix's; the whole disk is not to be offered.  The
#      console alone, no desktop.
#      tools/mac-stage1.sh then puts on that ESP what a Mac's recovery
#      system is to find there (aarch64).
#   3. the first disk is started by EFI firmware, as a machine would
#      start it, and the person the installer was told of logs in over
#      SSH and looks: all of the system started, /usr is checked against
#      its hash, the account is as asked, the machine's firmware is
#      there and the kernel told of it, the kernel found the wireless
#      regulatory database, and the first boot left the partitions where
#      they were; and the desktop extension is laid over /usr, and its
#      login screen started
#   4. the same of the second disk, which has no desktop; and Apple's
#      partitions and the other system's ESP are then what they were
#      before the installer ran, byte for byte
#   5. the second disk again, started by U-Boot: the EFI firmware a Mac
#      is given (nix/boot.nix), here as built for this virtual machine;
#      and Apple's partitions are still what they were (aarch64)
#   6. from the live stick again, onto a third disk, laid out as a PC's
#      with Windows and bunix 0.4.0 (the testbed's): an ESP of 100 MB
#      with Windows' loader in the place firmware starts by default and
#      0.4.0's shim in EFI/bunix, a firmware entry for that shim,
#      Windows' reserved, data and recovery partitions, and 0.4.0's
#      XBOOTLDR, /usr slots and root.  The installer replaces the earlier
#      bunix: the kernel images get an XBOOTLDR partition again,
#      systemd-boot goes in EFI/bunix in the shim's place, and one
#      firmware entry for it comes first (x86_64)
#   7. that disk starts bunix by the firmware's entry; and Windows'
#      partitions, their lines in the partition table, and Windows'
#      loader are what they were (x86_64)
#
# The person's way in is a key this test puts in their home after the
# installer has finished: the installed system takes no password over
# SSH, and root's account is locked.  NOT tested: a login at the console
# with the password, a Mac's ESP with another system's loader, or what
# another system on the Mac is started by (both are to be refused), a
# Windows that starts (its partitions hold nothing that would),
# U-Boot as built for a Mac, on one, and a driver that gets its firmware
# when it is asked again (no device here wants any).
#
#   BUNIX_ARCHITECTURE, BUNIX_X86_BUILDER
#                    tools/test-machine.sh
#   BUNIX_SSH_KEY    the public key the test logs in with; default
#                    ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT   the Mac's port for the machine's SSH; default 2022
#
# Needs: what tools/boot-vm.sh needs.
set -eu

ssh_port=${BUNIX_SSH_PORT:-2022}
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
if [ ! -f "$public_key_file" ]; then
    echo "install-test.sh: no public key in $public_key_file to log in with" >&2
    exit 1
fi

fail() {
    echo "install-test.sh: FAILED: $*" >&2
    echo "the machine's console is in $work/console.log" >&2
    exit 1
}
# However this script ends, the machine does not stay behind it, holding
# the port.
qemu=
clean_up() {
    kill $qemu 2> /dev/null || true
    wait 2> /dev/null || true
}
trap clean_up EXIT
if nc -z 127.0.0.1 "$ssh_port" 2> /dev/null; then
    echo "install-test.sh: port $ssh_port of this Mac is in use" >&2
    exit 1
fi

tool=install-test.sh
. "$(dirname "$0")/test-machine.sh"
# What only an Apple Silicon Mac has is tested on a machine of its kind:
# the files its boot loader loads, U-Boot, firmware of the machine's own.
# (The x86_64 machine is a PC with the same two disks, the second as a
# Mac with Intel's processor has it; its firmware starts systemd-boot
# itself.)
like_an_apple_silicon_mac=no
if [ "$architecture" = aarch64 ]; then
    like_an_apple_silicon_mac=yes
fi
# How the system in memory is started: a Mac's as tools/boot-mac.sh
# starts it, a PC's from the live image (images/live.nix), as a person
# would start one
starts_from_live_image=no
if [ "$architecture" = x86_64 ]; then
    starts_from_live_image=yes
fi
# What only a PC has is tested on the PC: Windows beside bunix, and the
# firmware's boot entries
like_a_windows_pc=no
if [ "$architecture" = x86_64 ]; then
    like_a_windows_pc=yes
fi
prepare_machine
version=$(release_version)
if [ $like_an_apple_silicon_mac = yes ]; then
    u_boot=$(build "$source/nix/boot.nix" -A u-boot-qemu)
    copy_built_file_to_machine "$u_boot/usr/lib/u-boot/qemu/u-boot-nodtb.bin" u-boot.bin
fi

# Empty, and as large as they are only in name: what is written of them
# is all that is kept.
in_machine_directory "truncate -s 16G whole.raw && truncate -s 24G mac.raw && truncate -s 24G windows.raw"

# ---- Machines --------------------------------------------------------------------

key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
# The machine's processor is the real one (tools/test-machine.sh).  But
# not for U-Boot: the Mac's hypervisor stops at an instruction of
# U-Boot's it cannot carry out.  QEMU plays the processor instead, `max`
# being the one of its processors with the 16K pages this kernel is
# built for.
machine_on_played_processor="-M virt -accel tcg,thread=multi -cpu max"
# The second is given sectors of 4096 bytes, wherever it is attached.
# Both are in QEMU's list of what to start (bootindex), after a PC's live
# stick: the PC's firmware keeps only what that list names, from the
# stick's start on, and would otherwise not try the disk it is started
# with later.
whole_disk="-drive file=$machine_directory/whole.raw,format=raw,if=none,id=whole -device virtio-blk-pci,drive=whole,bootindex=1"
mac_disk="-drive file=$machine_directory/mac.raw,format=raw,if=none,id=mac -device virtio-blk-pci,drive=mac,logical_block_size=4096,physical_block_size=4096,bootindex=2"

# as <user> <command>: on the machine, over SSH
# (a name no other function has for a variable: sh has one of each name)
as() {
    logging_in_as=$1
    shift
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR -o BatchMode=yes "$logging_in_as@127.0.0.1" "$@"
}
# answers_within <seconds> <user>: does the machine take their login in
# that time?
answers_within() {
    deadline=$(($(date +%s) + $1))
    until as "$2" true 2> /dev/null; do
        machine_is_gone=no
        kill -0 $qemu 2> /dev/null || machine_is_gone=yes
        if [ $machine_is_gone = yes ] || [ "$(date +%s)" -ge $deadline ]; then
            return 1
        fi
        sleep 2
    done
}
# The system in memory is powered off, as a person would, so that what it
# wrote is on the disks.
power_off() {
    as root systemctl poweroff || true
    deadline=$(($(date +%s) + 60))
    while kill -0 $qemu 2> /dev/null; do
        [ "$(date +%s)" -lt $deadline ] || fail "the machine was told to power off, and is still running"
        sleep 1
    done
}
# An installed one is ended as a machine whose plug is pulled: its disk
# is not looked at again, and the person logged in may not power it off
# from afar without their password.
pull_the_plug() {
    end_qemu
}

# ---- Installing --------------------------------------------------------------------

if [ $starts_from_live_image = no ]; then
    echo "building the system, and the files of its version"
    image=$(build "$source/nix/images/system.nix")
    update=$(build "$source/nix/images/update.nix")
    # the kernel the system was built with: its modules are in the image
    copy_built_file_to_machine "$image/usr-partition/vmlinuz" vmlinuz
    copy_built_file "$image/initramfs.cpio.gz" "$work/initramfs.cpio.gz"
    mkdir "$work/files"
    copy_built_directory "$update" "$work/files"
    # named as a release names it (tools/publish.sh), which the installer
    # looks for
    desktop=$(build "$source/nix/images/desktop.nix" -A image)
    copy_built_file "$desktop/desktop_*.raw" "$work/files/desktop_$version.$architecture_in_file_names.raw"

    # The machine is handed firmware of its own, as tools/boot-mac.sh
    # hands a Mac its: an archive before the image, not compressed, and
    # the kernel told of its directory.  One file that no driver asks
    # for; what is tested is that the installed systems still have it,
    # and look there.
    rm -rf "$work/firmware"
    mkdir -p "$work/firmware/vendorfw"
    echo "a file of the machine's own" > "$work/firmware/vendorfw/install-test"
    (cd "$work/firmware" && find vendorfw | cpio -o -H newc --quiet > "$work/firmware.cpio")
    cat "$work/firmware.cpio" "$work/initramfs.cpio.gz" > "$work/initramfs-with-firmware"
    send_to_machine initramfs-with-firmware

    echo "starting bunix in memory, with the two disks"
    # shellcheck disable=SC2086  # the disks' words are several each
    start_qemu $machine_on_real_processor -kernel "$machine_directory/vmlinuz" -initrd "$machine_directory/initramfs-with-firmware" \
        -append "console=$console quiet firmware_class.path=/vendorfw $key_word" $whole_disk $mac_disk
    answers_within 90 root || fail "the system in memory did not answer on SSH"
    # (--no-xattrs: not what macOS notes about a file it copied)
    tar -C "$work/files" --no-xattrs -cf - . | as root 'mkdir -p /root/install && tar -xf - -C /root/install' \
        || fail "could not give the machine the version's files"
    files=/root/install
else
    echo "building the live image"
    live=$(build "$source/nix/images/live.nix" -A image)
    copy_built_file_to_machine "$live/bunix-$architecture_in_file_names-live.img" live.img
    # as large as a stick is, so that the installer leaves it out for
    # having its files on it, and not for being too small for bunix
    in_machine_directory "truncate -s 16G live.img"

    echo "starting bunix in memory from the live image, a USB stick, with the two disks"
    # Started first (bootindex), read-only as a stick that is not written
    # to.  The serial console and the key: words the firmware hands the
    # kernel image's command line (SMBIOS), as tools/desktop-test.sh has
    # them.
    stick="-device qemu-xhci -drive file=$machine_directory/live.img,format=raw,if=none,id=stick,readonly=on -device usb-storage,drive=stick,bootindex=0"
    smbios_words=$(printf 'console=%s %s' "$console" "$key_word" | sed 's/,/,,/g')
    # shellcheck disable=SC2086
    start_qemu $machine_on_real_processor $efi_firmware $stick $whole_disk $mac_disk \
        -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
    answers_within 120 root || fail "the system in memory, from the live image, did not answer on SSH"
    files=/run/bunix/medium/install
    as root "ls $files/bunix_$version.$architecture_in_file_names.efi" > /dev/null \
        || fail "the live image's files are not at $files"
    # /usr from the stick, checked against its hash, and the root in memory
    [ "$(as root "findmnt -no SOURCE /usr")" = /dev/mapper/usr ] \
        || fail "the live system's /usr is not the stick's, checked against its hash"
    [ "$(as root "findmnt -no FSTYPE /")" = tmpfs ] || fail "the live system's root is not in memory"
fi

# The disks by what was asked of QEMU, not by the order Linux found them in
disk_with_sectors_of() {
    as root "for disk in /dev/vda /dev/vdb; do [ \$(blockdev --getss \$disk) != $1 ] || echo \$disk; done"
}
whole=$(disk_with_sectors_of 512)
mac=$(disk_with_sectors_of 4096)
[ -n "$whole" ] && [ -n "$mac" ] || fail "the machine does not have the two disks: '$whole' '$mac'"
# The number the installer lists a disk under: it lists what lsblk does,
# in that order, but for what is too small for bunix, and the disk its
# files are on.  Here that is the virtual machine's flash chip, the swap
# in memory, which a PC's kernel lists before its disks, and a PC's live
# stick (sd*: the test's own two disks are vd*).
number_of() {
    as root "lsblk -ndpo NAME,TYPE | awk '\$2 == \"disk\" && \$1 !~ /mtdblock|zram|^\\/dev\\/sd/ { number++; if (\$1 == \"$1\") print number }'"
}

# run_installer <name of the log> <answers, a line each>: fails the test
# if the installer does
run_installer() {
    printf '%s\n' "$2" | as root "bunix-install $files" > "$work/install-$1.log" 2>&1 \
        || fail "the installer failed; see $work/install-$1.log"
}
# The partition of a disk with this name, as a device
partition_named() {
    as root "lsblk -nrpo NAME,PARTLABEL $1 | sed -n 's| $2\$||p'"
}
# The root partition an installer made on <disk>, mounted on the system
# in memory, before the machine is ever started from it
mount_new_root() {
    root_partition=$(partition_named "$1" bunix-root)
    [ -n "$root_partition" ] || fail "$1 has no partition named bunix-root"
    as root "mkdir -p /run/new-root && mount $root_partition /run/new-root" || fail "could not mount $root_partition"
}
expect_root_locked() {
    mount_new_root "$1"
    root_in_shadow=$(as root "grep '^root:' /run/new-root/etc/shadow; umount /run/new-root")
    case $root_in_shadow in
        'root:!'*) ;;
        *) fail "root's password on $1 is not locked" ;;
    esac
}
# The test's own way in to what was installed on <disk>: its key, in
# <user>'s home.  Not something the installer does.
give_key_to() {
    mount_new_root "$1"
    as root "install -d -m 700 /run/new-root/home/$2/.ssh &&
        cat > /run/new-root/home/$2/.ssh/authorized_keys &&
        chown -R --reference=/run/new-root/home/$2 /run/new-root/home/$2/.ssh &&
        umount /run/new-root" < "$public_key_file" || fail "could not put the test's key in $2's home on $1"
}
# What the first boot must leave as it is: where each partition is, to
# the byte.  (Without the devices' names: the disk has another when it is
# the machine's only one.  And without the partitions': lsblk tells only
# root.)
partitions_of() {
    # partitions alone: a running system's /usr is a device on top of two
    as "$1" "lsblk -b -nro TYPE,START,SIZE $2 | grep '^part '"
}

echo "1. onto a whole, empty disk, with the desktop"
# The whole disk (1), then the desktop (1)
run_installer whole "$(number_of "$whole")
1
1
Whole-Disk
Sara of the Whole Disk
sara
2
a password with spaces
a password with spaces
$whole"
if grep -q mtdblock "$work/install-whole.log"; then
    fail "the machine's flash chip was offered as a disk to install to"
fi
if [ $starts_from_live_image = yes ] && grep -q "/dev/sd" "$work/install-whole.log"; then
    fail "the live stick the files are on was offered as a disk to install to"
fi
expect_root_locked "$whole"
give_key_to "$whole" sara
partitions_of root "$whole" > "$work/whole-partitions"

echo "2. onto a disk laid out as a Mac's, in place of an earlier Linux"
# Apple's types: the container its firmware keeps its state in, APFS
# (macOS, and the small one a second system starts from), recovery.
# What must be left alone, as "start:size" in MiB, for the Mac's side to
# read back (below): Apple's four, and the other system's ESP.
apples_partitions="1:100 101:2048 2149:500 23551:1024"
left_alone="$apples_partitions 2649:300"
as root "sfdisk -q $mac" <<'END' || fail "could not lay the Mac's disk out"
label: gpt
start=1MiB, size=100MiB, type=69646961-6700-11AA-AA11-00306543ECAC, name="iBootSystemContainer"
start=101MiB, size=2048MiB, type=7C3457EF-0000-11AA-AA11-00306543ECAC, name="Container"
start=2149MiB, size=500MiB, type=7C3457EF-0000-11AA-AA11-00306543ECAC, name="Container"
start=2649MiB, size=300MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="other-esp"
start=2949MiB, size=1024MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="bunix-esp"
start=3973MiB, size=12288MiB, type=B921B045-1DF0-41C3-AF44-4C6F280D3FAE, name="bunix-root"
start=23551MiB, size=1024MiB, type=52637672-7900-11AA-AA11-00306543ECAC, name="RecoveryOSContainer"
END
# Something in each of Apple's, to be found again.  The other system's
# ESP with a loader of its own, though not where firmware would start
# it; bunix's with nothing on it, and a root with a file system, as mbp20
# has them.
as root "set -e
    for number in 1 2 3 7; do
        dd if=/dev/urandom of=$mac\$number bs=1M count=8 status=none
    done
    mkfs.vfat -F 32 -n OTHER ${mac}4 > /dev/null
    mkdir -p /run/other-esp
    mount ${mac}4 /run/other-esp
    mkdir -p /run/other-esp/EFI/other
    head -c 100000 /dev/urandom > /run/other-esp/EFI/other/loader.efi
    umount /run/other-esp
    mkfs.vfat -F 32 -n BUNIX-ESP ${mac}5 > /dev/null
    mkfs.ext4 -q -F ${mac}6
    sync
    udevadm settle" || fail "could not fill the Mac's disk"
# Read from the disk's file, where it is: not what the machine says of it
# checksums_of <disk's file> <stretches>
checksums_of() {
    for stretch in $2; do
        in_machine_directory "dd if=$1 bs=1048576 skip=${stretch%:*} count=${stretch#*:} 2> /dev/null | sha256sum"
    done
}
# and their lines in the partition table: type, id, name, place
table_lines_of_what_is_left_alone() {
    as root "sfdisk -d $mac | grep -i -e aa11-00306543ecac -e other-esp"
}
checksums_of mac.raw "$left_alone" > "$work/left-alone-before"
checksums_of mac.raw "$apples_partitions" > "$work/apples-before"
table_lines_of_what_is_left_alone > "$work/table-before"
bunix_esp_id=$(as root "lsblk -ndo PARTUUID ${mac}5")

# Its places: the root partition (1), the Linux system (2), the free
# space after it (3).  Not the whole disk.  Then which of the two ESPs:
# the second.  Then the console (2).
run_installer mac "$(number_of "$mac")
2
2
2
mac-laptop
Adam of the Mac
adam
1
another password
another password
$mac"
grep -q '2) replace the Linux system' "$work/install-mac.log" \
    || fail "the second place offered was not the Linux system; see $work/install-mac.log"
if grep -q 'erases everything' "$work/install-mac.log"; then
    fail "the whole of a Mac's disk was offered"
fi
table_lines_of_what_is_left_alone > "$work/table-after"
cmp -s "$work/table-before" "$work/table-after" \
    || fail "the installer changed the partition table's lines of what it was to leave alone"
# what starts a Mac is told the ESP by this id; and it is the one chosen
# that has the boot files
[ "$(as root "lsblk -ndo PARTUUID ${mac}5")" = "$bunix_esp_id" ] || fail "bunix's ESP is not the partition it was"
as root "mount -o ro ${mac}5 /run/other-esp && ls /run/other-esp/EFI/Linux/bunix_$version.efi && umount /run/other-esp" > /dev/null \
    || fail "the ESP that was chosen does not have bunix's kernel image"
if [ $like_an_apple_silicon_mac = yes ]; then
    # and what a Mac's own boot loader loads from it, whole
    as root "mount -o ro ${mac}5 /run/other-esp && cmp /usr/lib/mac-stage2/stage2.bin /run/other-esp/aurora/stage2.bin && umount /run/other-esp" \
        || fail "the ESP that was chosen does not have what a Mac's boot loader loads (aurora/stage2.bin)"
    grep -q "tools/mac-stage1.sh $bunix_esp_id put " "$work/install-mac.log" \
        || fail "the installer did not say how the Mac is told of the ESP; see $work/install-mac.log"
    # and that, done: what the Mac's recovery system is to find is on the ESP,
    # whole (the first stage made for it, by its checksum)
    # (made in the test's own directory: the default one may have the files
    # of a real Mac)
    BUNIX_STAGE1_DIRECTORY="$work/mac-stage1" "$(dirname "$0")/mac-stage1.sh" "$bunix_esp_id" put "ssh://root@127.0.0.1:$ssh_port" \
        > "$work/mac-stage1.log" 2>&1 \
        || fail "tools/mac-stage1.sh could not put its files on the ESP; see $work/mac-stage1.log"
    as root "mount -o ro ${mac}5 /run/other-esp" || fail "could not mount the ESP that was chosen"
    files_on_the_esp=$(as root "cd /run/other-esp/bunix-enroll && LC_ALL=C ls | tr '\n' ' '")
    checksum_on_the_esp=$(as root "md5sum /run/other-esp/bunix-enroll/aura-stage1.bin | cut -d' ' -f1")
    as root "umount /run/other-esp"
    [ "$files_on_the_esp" = "aura-stage1.bin aura.bin enroll-stage1.sh enroll.sh way-back.sh " ] \
        || fail "the ESP does not have the files the Mac's recovery system needs, but: $files_on_the_esp"
    [ "$checksum_on_the_esp" = "$(md5 -q "$work/mac-stage1/aura-stage1.bin")" ] \
        || fail "the first stage on the ESP is not the one that was made"
fi
expect_root_locked "$mac"
give_key_to "$mac" adam
partitions_of root "$mac" > "$work/mac-partitions"
power_off

# ---- Starting what was installed ---------------------------------------------------

# same_but_for_the_last_megabyte <partitions before> <partitions now>
#
# Every partition starts where it did and is as large, but that the last,
# the root partition, may have grown by less than a megabyte: sfdisk ends
# a partition on a whole megabyte, and the first boot's systemd-repart
# gives the root partition what is left to the disk's end.
same_but_for_the_last_megabyte() {
    paste -d ' ' "$1" "$2" | awk '
        # a line: part <start> <size> part <start> <size>
        { grown = $6 - $3 }
        $2 != $5 || grown < 0 || grown >= 1048576 { changed = 1 }
        grown > 0 { partitions_grown++; last_grown = NR }
        END {
            if (partitions_grown > 1) changed = 1
            if (partitions_grown == 1 && last_grown != NR) changed = 1
            exit changed
        }'
}
# expect_installed <user> <their name> <their shell> <the machine's name>
#     <the file of its partitions before>: what the person finds, logged
# in to the machine just started.  The one disk it has is /dev/vda.
expect_installed() {
    user=$1
    full_name=$2
    shell=$3
    host_name=$4
    partitions_before=$5
    answers_within 120 "$user" || fail "$user could not log in to the installed system"
    state=$(as "$user" systemctl is-system-running --wait || true)
    [ "$state" = running ] || fail "not all of the installed system started: $state"
    running=$(as "$user" "sed -n 's/^IMAGE_VERSION=//p' /usr/lib/os-release")
    [ "$running" = "$version" ] || fail "bunix $running started, not $version"
    # The first mount on /usr: an extension laid over it (the desktop) is
    # a mount on top of that one
    usr_device=$(as "$user" "awk '\$2 == \"/usr\" { print \$1; exit }' /proc/self/mounts")
    [ "$usr_device" = /dev/mapper/usr ] || fail "/usr is not checked against its hash: $usr_device"
    # (udev's link, not lsblk: only root is told a partition's name by it)
    [ "$(as "$user" findmnt -no SOURCE /)" = "$(as "$user" readlink -f /dev/disk/by-partlabel/bunix-root)" ] \
        || fail "/ is not the partition the installer made"
    [ "$(as "$user" hostname)" = "$host_name" ] || fail "the machine's name is not $host_name"
    account=$(as "$user" "getent passwd $user")
    case $account in
        "$user:"*":$full_name:/home/$user:$shell") ;;
        *) fail "the account is not as asked: $account" ;;
    esac
    as "$user" id -nG | tr ' ' '\n' | grep -q -x wheel || fail "$user is not an administrator (wheel)"
    # A PC's firmware is in /usr, and its kernel is not to look on the
    # root partition first
    # (system/usr/lib/systemd/system/vendor-firmware.service).
    if [ $like_an_apple_silicon_mac = yes ]; then
        [ "$(as "$user" cat /var/lib/vendorfw/install-test)" = "a file of the machine's own" ] \
            || fail "the installed system does not have the firmware the machine was handed"
        [ "$(as "$user" cat /sys/module/firmware_class/parameters/path)" = /var/lib/vendorfw ] \
            || fail "the kernel was not told where the machine's firmware is"
    fi
    # The kernel asks for it before /usr is there (nix/images/initrd.nix)
    if as "$user" journalctl --dmesg --boot --no-pager | grep -q "failed to load regulatory.db"; then
        fail "the kernel did not find the wireless regulatory database"
    fi
    partitions_of "$user" /dev/vda > "$work/partitions-now"
    same_but_for_the_last_megabyte "$partitions_before" "$work/partitions-now" \
        || fail "the first boot changed the partitions: $(cat "$work/partitions-now")"
    echo "  started: bunix $running, systemd $state, $user logged in"
}

echo "3. the whole disk starts, and Sara logs in to fish"
# shellcheck disable=SC2086
start_qemu $machine_on_real_processor $efi_firmware $whole_disk
expect_installed sara "Sara of the Whole Disk" /usr/bin/fish whole-disk "$work/whole-partitions"
# Merged before the system counts as started; greetd, upheld once it is,
# may still be on its way
as sara "test -e /usr/lib/extension-release.d/extension-release.desktop" \
    || fail "the desktop extension is not laid over /usr"
as sara "timeout 60 sh -c 'until systemctl is-active -q greetd.service; do sleep 1; done'" \
    || fail "the desktop's login screen did not start"
as sara "test -e /etc/sysupdate.d/desktop.feature.d/enable.conf" \
    || fail "the desktop is not enabled for updates"
echo "  the desktop is laid over /usr, enabled, and its login screen started"
pull_the_plug

echo "4. the Mac's disk starts, and Adam logs in to bash"
# shellcheck disable=SC2086
start_qemu $machine_on_real_processor $efi_firmware $mac_disk
expect_installed adam "Adam of the Mac" /usr/bin/bash mac-laptop "$work/mac-partitions"
# (said, not an exit status: an SSH that fails would pass for "no")
has_the_desktop=$(as adam "test -e /usr/lib/extension-release.d/extension-release.desktop && echo yes || echo no")
[ "$has_the_desktop" = no ] || fail "the console install has the desktop: $has_the_desktop"
# The disk is started once more (5), and this was its first start, which
# filled /etc: without the sync, the plug pulled now leaves some of those
# files empty, and the next start without a message bus.  (A machine
# that loses power right after its first start is left so too:
# docs/nix-usr-system.md, open questions.)
as adam sync
pull_the_plug
checksums_of mac.raw "$left_alone" > "$work/left-alone-after"
cmp -s "$work/left-alone-before" "$work/left-alone-after" \
    || fail "one of Apple's partitions, or the other system's ESP, is not what it was before the installer ran"
echo "  Apple's partitions and the other system's ESP: as they were"

if [ $like_an_apple_silicon_mac = yes ]; then
    echo "5. the Mac's disk starts through U-Boot too"
    # shellcheck disable=SC2086
    start_qemu $machine_on_played_processor -bios "$machine_directory/u-boot.bin" $mac_disk
    expect_installed adam "Adam of the Mac" /usr/bin/bash mac-laptop "$work/mac-partitions"
    pull_the_plug
    # U-Boot keeps EFI's variables in a file on an ESP, and here that is the
    # first ESP of the disk, the other system's: this U-Boot is not told
    # which.  A Mac's is, by aura (the one written into its first stage,
    # bunix's).  So of what was to be left alone, Apple's partitions are
    # looked at once more, and that ESP is not.
    checksums_of mac.raw "$apples_partitions" > "$work/apples-after-u-boot"
    cmp -s "$work/apples-before" "$work/apples-after-u-boot" \
        || fail "one of Apple's partitions is not what it was before U-Boot started the disk"
    echo "  Apple's partitions: as they were"
fi

if [ $like_a_windows_pc = yes ]; then
    echo "6. from the live stick, onto a disk laid out as a PC's with Windows and bunix 0.4.0"
    # Given no place in QEMU's list of what to start (bootindex), so that
    # the firmware goes by its own boot entries when the disk is started
    # alone (7); while the stick is in, the stick comes first.  An id it
    # is found by in the system in memory.
    windows_disk="-drive file=$machine_directory/windows.raw,format=raw,if=none,id=windows -device virtio-blk-pci,drive=windows,serial=windows"
    start_from_the_stick_with_the_windows_disk() {
        # shellcheck disable=SC2086
        start_qemu $machine_on_real_processor $efi_firmware $stick $windows_disk \
            -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
        answers_within 120 root || fail "the system in memory, from the live image, did not answer on SSH"
        windows=$(as root "readlink -f /dev/disk/by-id/virtio-windows")
    }
    start_from_the_stick_with_the_windows_disk
    # As Windows' installer makes a disk -- its ESP of 100 MB, the
    # reserved partition, its data, its recovery partition -- and then
    # bunix 0.4.0's installer: an XBOOTLDR partition for its kernel
    # images, its /usr slots, its root.  Windows' as "start:size" in MiB,
    # for checksums (below): what bunix-install is to leave alone.
    windows_partitions="101:16 117:8192 8309:600"
    as root "sfdisk -q $windows" <<'END' || fail "could not lay the Windows PC's disk out"
label: gpt
start=1MiB, size=100MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI system partition"
start=101MiB, size=16MiB, type=E3C9E316-0B5C-4DB8-817D-F92DF00215AE, name="Microsoft reserved partition"
start=117MiB, size=8192MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name="Basic data partition"
start=8309MiB, size=600MiB, type=DE94BBA4-06D1-4D40-A16A-BFD50179D6AC
start=8909MiB, size=1024MiB, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="XBOOTLDR"
start=9933MiB, size=2048MiB, type=8484680C-9521-48C6-9C11-B0720656F69E, name="bunix_0.4.0"
start=11981MiB, size=32MiB, type=77FF5F63-E7B6-4633-ACF4-1565B864C0E6, name="bunix_0.4.0_verity"
start=12013MiB, size=2048MiB, type=8484680C-9521-48C6-9C11-B0720656F69E, name="_empty"
start=14061MiB, type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name="root"
END
    # Something in each of Windows' partitions, to be found again; on its
    # ESP its loader, where Windows puts it and in the place firmware
    # starts by default, and 0.4.0's shim, with a firmware entry for it
    as root "set -e
        for number in 2 3 4; do
            dd if=/dev/urandom of=${windows}\$number bs=1M count=8 status=none
        done
        mkfs.vfat -F 32 -n SYSTEM ${windows}1 > /dev/null
        mkdir -p /run/windows-esp
        mount ${windows}1 /run/windows-esp
        mkdir -p /run/windows-esp/EFI/Microsoft/Boot /run/windows-esp/EFI/BOOT /run/windows-esp/EFI/bunix
        head -c 1500000 /dev/urandom > /run/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi
        cp /run/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi /run/windows-esp/EFI/BOOT/BOOTX64.EFI
        head -c 900000 /dev/urandom > /run/windows-esp/EFI/bunix/shimx64.efi
        head -c 100000 /dev/urandom > /run/windows-esp/EFI/bunix/grubx64.efi
        umount /run/windows-esp
        efibootmgr --quiet --create --disk $windows --part 1 --label bunix --loader '\\EFI\\bunix\\shimx64.efi'
        sync
        udevadm settle" || fail "could not fill the Windows PC's disk"
    windows_checksums() {
        checksums_of windows.raw "$windows_partitions"
        as root "mkdir -p /run/windows-esp && mount -o ro ${windows}1 /run/windows-esp &&
            sha256sum /run/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi /run/windows-esp/EFI/BOOT/BOOTX64.EFI;
            umount /run/windows-esp"
        as root "sfdisk -d $windows | grep -i -e e3c9e316 -e ebd0a0a2 -e de94bba4 -e 'EFI system partition'"
    }
    windows_checksums > "$work/windows-before"
    # Its places: each partition but the ESP (1-8), the earlier bunix 0.4.0
    # (9), the whole disk (10).  The earlier bunix; the console (2); bash
    # (1); the disk's name to go on.
    run_installer windows "$(number_of "$windows")
9
2
windows-pc
Wendy of the PC
wendy
1
the password of Wendy
the password of Wendy
$windows"
    grep -q '9) replace the earlier bunix 0.4.0' "$work/install-windows.log" \
        || fail "the ninth place offered was not the earlier bunix; see $work/install-windows.log"
    [ -n "$(partition_named "$windows" bunix-boot)" ] \
        || fail "the installer made no XBOOTLDR partition beside the ESP of 100 MB; see $work/install-windows.log"
    as root "efibootmgr" > "$work/boot-entries" 2>&1
    first_entry=$(sed -n 's/^BootOrder: \([0-9A-F]*\).*/\1/p' "$work/boot-entries")
    grep -q -E "^Boot$first_entry\*? bunix" "$work/boot-entries" \
        || fail "the firmware's first boot entry is not bunix's; see $work/boot-entries"
    [ "$(grep -c -E '^Boot[0-9A-F]{4}[* ] bunix' "$work/boot-entries")" = 1 ] \
        || fail "the firmware has more than one entry for bunix (0.4.0's is to go); see $work/boot-entries"
    as root "mount -o ro ${windows}1 /run/windows-esp && ls /run/windows-esp/EFI/bunix; umount /run/windows-esp" > "$work/esp-bunix" 2>&1
    # this bunix's: shim, systemd-boot beside it under shim's name for it,
    # MokManager and bunix's certificate; 0.4.0's shim was a file of
    # random bytes, and is gone
    [ "$(tr '\n' ' ' < "$work/esp-bunix")" = "bunix.cer grubx64.efi mmx64.efi shimx64.efi " ] \
        || fail "EFI/bunix is not this bunix's shim and systemd-boot: $(cat "$work/esp-bunix")"
    as root "mount -o ro ${windows}1 /run/windows-esp && cmp /usr/lib/shim/shimx64.efi /run/windows-esp/EFI/bunix/shimx64.efi; umount /run/windows-esp" \
        || fail "EFI/bunix/shimx64.efi is not this bunix's shim (0.4.0's was to be replaced)"
    expect_root_locked "$windows"
    give_key_to "$windows" wendy
    partitions_of root "$windows" > "$work/windows-partitions"
    power_off

    echo "7. the Windows PC's disk starts bunix, by the firmware's entry for it"
    # shellcheck disable=SC2086
    start_qemu $machine_on_real_processor $efi_firmware $windows_disk
    expect_installed wendy "Wendy of the PC" /usr/bin/bash windows-pc "$work/windows-partitions"
    # /boot is mounted when it is first looked at (an automount): looked at
    # first, and then its partition asked for
    boot_device=$(as wendy "ls /boot > /dev/null 2>&1; findmnt -n -o SOURCE /boot | tail -1")
    [ "$boot_device" = "$(as wendy "readlink -f /dev/disk/by-partlabel/bunix-boot")" ] \
        || fail "the XBOOTLDR partition is not the one at /boot, where updates put kernel images: $boot_device"
    as wendy sync
    pull_the_plug
    # (the stick in again, for the system in memory to look with)
    start_from_the_stick_with_the_windows_disk
    windows_checksums > "$work/windows-after"
    power_off
    cmp -s "$work/windows-before" "$work/windows-after" \
        || fail "Windows' partitions, their lines in the table, or its loader are not what they were before the installer ran"
    echo "  Windows' partitions and loader: as they were"
fi

echo "install-test.sh: passed"

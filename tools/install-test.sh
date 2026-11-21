#!/bin/sh
# Tests bunix-install (nix/images/system/usr/bin/bunix-install) in a
# virtual machine on an Apple Silicon Mac:
#
#   tools/install-test.sh
#
# bunix is started in memory, as on a machine it is to be installed on,
# with two disks, and is given the files of its own version
# (nix/images/update.nix).  It installs twice:
#
#   1. onto a whole, empty disk
#   2. onto a disk laid out as a Mac's is, with sectors of 4096 bytes as
#      a Mac's has: Apple's partitions before and after, and between them
#      another system's ESP, an ESP for bunix, a root partition of an
#      earlier Linux, and free space (what mbp20's disk has, and an ESP
#      more).  The installer replaces the Linux partition, and is told
#      which ESP is bunix's; the whole disk is not to be offered.
#   3. the first disk is started by EFI firmware, as a machine would
#      start it, and the person the installer was told of logs in over
#      SSH and looks: all of the system started, /usr is checked against
#      its hash, the account is as asked, and the first boot left the
#      partitions where they were
#   4. the same of the second disk; and Apple's partitions and the other
#      system's ESP are then what they were before the installer ran,
#      byte for byte
#
# The person's way in is a key this test puts in their home after the
# installer has finished: the installed system takes no password over
# SSH, and root's account is locked.  NOT tested: a login at the console
# with the password, a disk whose ESP has another system's loader, and
# real firmware (U-Boot on a Mac).
#
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

# nix-build prints the store path of what it built, and nothing else, on
# its standard output.  No pipe after it: a failed build has to stop this
# script.
build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link
}
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

work=${TMPDIR:-/tmp}/bunix-install-test
rm -rf "$work"
mkdir -p "$work/files"

# ---- What is installed, and what installs it ------------------------------------

echo "building the system, and the files of its version"
kernel=$(build /bunix/nix/boot.nix -A linux)
image=$(build /bunix/nix/images/system.nix)
update=$(build /bunix/nix/images/update.nix)
# the kernel is in a directory named after its release
vmlinuz=$(limactl shell bunix-builder sh -c "echo $kernel/usr/lib/modules/*/vmlinuz")
limactl copy "bunix-builder:$vmlinuz" "$work/vmlinuz"
limactl copy "bunix-builder:$image/initramfs.cpio.gz" "$work/initramfs.cpio.gz"
limactl copy -r "bunix-builder:$update/." "$work/files/"
# copied out of the store, where nothing can be written, or removed by
# the next run
chmod -R u+w "$work/files"
# the version, as Nix prints a string: in quotes
version=$(limactl shell bunix-builder nix-instantiate --eval /bunix/nix/release.nix)
version=${version#\"}
version=${version%\"}

# Empty, and as large as they are only in name: the Mac keeps what is
# written of them.
truncate -s 16G "$work/whole.raw"
truncate -s 24G "$work/mac.raw"

# ---- Machines --------------------------------------------------------------------

key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
qemu_machine() {
    qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 4G \
        -netdev "user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22" -device virtio-net-pci,netdev=net \
        -nographic -no-reboot "$@" < /dev/null >> "$work/console.log" 2>&1 &
    qemu=$!
}
# The second is given sectors of 4096 bytes, wherever it is attached.
whole_disk="-drive file=$work/whole.raw,format=raw,if=none,id=whole -device virtio-blk-pci,drive=whole"
mac_disk="-drive file=$work/mac.raw,format=raw,if=none,id=mac -device virtio-blk-pci,drive=mac,logical_block_size=4096,physical_block_size=4096"
firmware=$(dirname "$(command -v qemu-system-aarch64)")/../share/qemu/edk2-aarch64-code.fd

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
    kill $qemu 2> /dev/null || true
    wait $qemu 2> /dev/null || true
}

# ---- Installing --------------------------------------------------------------------

echo "starting bunix in memory, with the two disks"
# shellcheck disable=SC2086  # the disks' words are several each
qemu_machine -kernel "$work/vmlinuz" -initrd "$work/initramfs.cpio.gz" \
    -append "console=ttyAMA0 quiet $key_word" $whole_disk $mac_disk
answers_within 90 root || fail "the system in memory did not answer on SSH"
# (--no-xattrs: not what macOS notes about a file it copied)
tar -C "$work/files" --no-xattrs -cf - . | as root 'mkdir -p /root/install && tar -xf - -C /root/install' \
    || fail "could not give the machine the version's files"

# The disks by what was asked of QEMU, not by the order Linux found them in
disk_with_sectors_of() {
    as root "for disk in /dev/vda /dev/vdb; do [ \$(blockdev --getss \$disk) != $1 ] || echo \$disk; done"
}
whole=$(disk_with_sectors_of 512)
mac=$(disk_with_sectors_of 4096)
[ -n "$whole" ] && [ -n "$mac" ] || fail "the machine does not have the two disks: '$whole' '$mac'"
# The number the installer lists a disk under: it lists what lsblk does,
# in that order (the virtual machine has a small flash chip as well).
number_of() {
    as root "lsblk -ndpo NAME,TYPE | awk '\$2 == \"disk\" { number++; if (\$1 == \"$1\") print number }'"
}

# run_installer <name of the log> <answers, a line each>: fails the test
# if the installer does
run_installer() {
    printf '%s\n' "$2" | as root 'bunix-install /root/install' > "$work/install-$1.log" 2>&1 \
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

echo "1. onto a whole, empty disk"
run_installer whole "$(number_of "$whole")
1
Whole-Disk
Sara of the Whole Disk
sara
2
a password with spaces
a password with spaces
$whole"
expect_root_locked "$whole"
give_key_to "$whole" sara
partitions_of root "$whole" > "$work/whole-partitions"

echo "2. onto a disk laid out as a Mac's, in place of an earlier Linux"
# Apple's types: the container its firmware keeps its state in, APFS
# (macOS, and the small one a second system starts from), recovery.
# What must be left alone, as "start size" in MiB, for the Mac's side to
# read back (below): Apple's four, and the other system's ESP.
left_alone="1:100 101:2048 2149:500 2649:300 23551:1024"
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
# Read on the Mac, from the disk's file: not what the machine says of it
checksums_of_what_is_left_alone() {
    for stretch in $left_alone; do
        dd if="$work/mac.raw" bs=1048576 skip="${stretch%:*}" count="${stretch#*:}" 2> /dev/null | shasum -a 256
    done
}
# and their lines in the partition table: type, id, name, place
table_lines_of_what_is_left_alone() {
    as root "sfdisk -d $mac | grep -i -e aa11-00306543ecac -e other-esp"
}
checksums_of_what_is_left_alone > "$work/left-alone-before"
table_lines_of_what_is_left_alone > "$work/table-before"
bunix_esp_id=$(as root "lsblk -ndo PARTUUID ${mac}5")

# Its places: the root partition (1), the Linux system (2), the free
# space after it (3).  Not the whole disk.  Then which of the two ESPs:
# the second.
run_installer mac "$(number_of "$mac")
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
    [ "$(as "$user" findmnt -no SOURCE /usr)" = /dev/mapper/usr ] || fail "/usr is not checked against its hash"
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
    partitions_of "$user" /dev/vda > "$work/partitions-now"
    same_but_for_the_last_megabyte "$partitions_before" "$work/partitions-now" \
        || fail "the first boot changed the partitions: $(cat "$work/partitions-now")"
    echo "  started: bunix $running, systemd $state, $user logged in"
}

echo "3. the whole disk starts, and Sara logs in to fish"
# shellcheck disable=SC2086
qemu_machine -bios "$firmware" $whole_disk
expect_installed sara "Sara of the Whole Disk" /usr/bin/fish whole-disk "$work/whole-partitions"
pull_the_plug

echo "4. the Mac's disk starts, and Adam logs in to bash"
# shellcheck disable=SC2086
qemu_machine -bios "$firmware" $mac_disk
expect_installed adam "Adam of the Mac" /usr/bin/bash mac-laptop "$work/mac-partitions"
pull_the_plug
checksums_of_what_is_left_alone > "$work/left-alone-after"
cmp -s "$work/left-alone-before" "$work/left-alone-after" \
    || fail "one of Apple's partitions, or the other system's ESP, is not what it was before the installer ran"
echo "  Apple's partitions and the other system's ESP: as they were"

echo "install-test.sh: passed"

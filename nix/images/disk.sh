# Makes the disk of images/disk.nix with systemd-repart, from the
# description of its partitions written here.
#
# $update is the result of images/update.nix: the contents of a /usr
# slot's three partitions, each a file with its partition's id in its
# name, and the kernel image that starts that /usr.
# $version, $partition_architecture: what those files are named by.
# $esp_size: the partition a machine boots from.
# $usr_slot_size, $usr_verity_size: a /usr slot's two larger partitions.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

# The files, by the names update.sh gives them; the * is the id.
name=$update/bunix_$version.usr-$partition_architecture
usr_file=$(echo $name.*.raw)
verity_file=$(echo $name-verity.*.raw)
signature_file=$(echo $name-verity-sig.*.raw)
uki=$update/bunix_$version.$partition_architecture.efi
[ -f "$usr_file" ] && [ -f "$verity_file" ] && [ -f "$signature_file" ] && [ -f "$uki" ]
# the id is what is between the last two dots of a name
id_of() {
    local name=${1%.raw}
    echo ${name##*.}
}

# ---- The partition a machine boots from ---------------------------------------

# A newly written disk has no entry in the machine's list of what to
# start, so the machine starts the file every EFI looks for,
# EFI/BOOT/BOOT<kind>.EFI: systemd-boot, which starts the newest unified
# kernel image in EFI/Linux.  x86 has shim there, for Secure Boot, which
# makes an entry for systemd-boot in a directory of bunix's own; here
# there is no shim, and a Mac's EFI keeps no entries.  So this is for a
# partition that is bunix's alone: on one shared, EFI/BOOT is whoever's
# came first.
mkdir -p tree/esp/EFI/BOOT tree/esp/EFI/Linux tree/esp/loader
# systemd-bootaa64.efi -> BOOTAA64.EFI
systemd_boot=$(echo /usr/lib/systemd/boot/efi/systemd-boot*.efi)
[ -f "$systemd_boot" ]
kind=$(basename $systemd_boot .efi)
kind=${kind#systemd-boot}
cp $systemd_boot tree/esp/EFI/BOOT/BOOT${kind^^}.EFI
# The menu stays hidden, and lists only bunix: no entries for other
# systems' loaders (as elements/system/esp.bst).
printf '%s\n' 'timeout 0' 'console-mode keep' 'auto-entries no' > tree/esp/loader/loader.conf
# under the name systemd-boot and sysupdate know an installed one by
cp $uki tree/esp/EFI/Linux/bunix_$version.efi
# the time of each file, which the partition keeps: the build's own would
# make every disk another
find tree -exec touch -h -d @$SOURCE_DATE_EPOCH {} +

# ---- The partitions -------------------------------------------------------------

partition() {
    local file=$1
    shift
    printf '%s\n' '[Partition]' "$@" > disk.d/$file
}
mkdir -p disk.d
partition 00-esp.conf Type=esp Format=vfat CopyFiles=/esp:/ \
    SizeMinBytes=$esp_size SizeMaxBytes=$esp_size
# Slot A: this system's images, block for block, each partition with the
# id its file is named by (a kernel image finds its /usr by them).  The
# labels carry the version: sysupdate reads what is installed from them.
partition 10-usr-a.conf Type=usr Label=bunix_$version \
    UUID=$(id_of $usr_file) CopyBlocks=$usr_file ReadOnly=yes \
    SizeMinBytes=$usr_slot_size SizeMaxBytes=$usr_slot_size
partition 11-usr-a-verity.conf Type=usr-verity Label=bunix_${version}_verity \
    UUID=$(id_of $verity_file) CopyBlocks=$verity_file ReadOnly=yes \
    SizeMinBytes=$usr_verity_size SizeMaxBytes=$usr_verity_size
# (the signature's partition is 16K whatever is asked: what systemd gives
# such a partition)
partition 12-usr-a-verity-sig.conf Type=usr-verity-sig Label=bunix_${version}_verity_sig \
    UUID=$(id_of $signature_file) CopyBlocks=$signature_file ReadOnly=yes
# Slot B: empty, and labelled so, which is where sysupdate writes the
# next version.
partition 20-usr-b.conf Type=usr Label=_empty \
    SizeMinBytes=$usr_slot_size SizeMaxBytes=$usr_slot_size
partition 21-usr-b-verity.conf Type=usr-verity Label=_empty \
    SizeMinBytes=$usr_verity_size SizeMaxBytes=$usr_verity_size
partition 22-usr-b-verity-sig.conf Type=usr-verity-sig Label=_empty

mkdir -p $out tmp
# --offline: without the loop devices a build does not have.
# --sector-size=512: the disk's and its file systems', said: left to
#   itself repart makes a FAT of 4096-byte sectors on a disk of 512-byte
#   ones, which Linux reads and other things that start machines do not.
#   A disk of 4096-byte sectors, as a Mac's, is not written from this
#   file.
# --seed: what the ids not given above are made of (the disk's, the
#   ESP's, the empty slot's), so that they are the same at every build.
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --sector-size=512 --definitions=disk.d --copy-source=/build/tree \
    --seed=$(printf 'bunix disk %s' $version | sha256sum | head -c 32) \
    $out/disk.raw

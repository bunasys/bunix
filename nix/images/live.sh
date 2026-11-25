# Makes the live image of images/live.nix: its kernel image with
# systemd's ukify, then the image itself with systemd-repart, as disk.sh
# makes a disk.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

usr=$system_image/usr-partition
mkdir -p tree/esp/EFI/BOOT tree/esp/EFI/Linux tree/esp/loader tree/esp/install

# The stick's one partition, by an id of its own, the same at every build
# of a version and another for every version: what the kernel image's
# command line mounts it by.  Not by its name, which every stick of every
# version has: with two sticks in, or a copy of one on a disk, the other
# would be mounted, its version installed, and this stick offered as a
# disk to install to.
partition_id=$(printf 'bunix live partition %s' $version | sha256sum | head -c 32 \
    | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')

# ---- The kernel image ------------------------------------------------------------

# As uki.sh makes an installed system's, but for the initramfs, which is
# the whole system and not the initrd that finds /usr on a disk.  No
# usrhash=: there is no /usr to find, and the system in memory has its
# own.  The stick's partition is mounted read-only where bunix-install is
# told to look, as a line of /etc/fstab would have it, which a system in
# memory has none of (systemd.mount-extra).  nofail: without the stick
# (pulled out, or not found) the system starts all the same.
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)
with_microcode=
if [ -n "$microcode" ]; then
    with_microcode=--microcode=$microcode/usr/lib/microcode/microcode.cpio
fi
kernel_image=tree/esp/EFI/Linux/bunix-live_$version.efi
mount_the_stick="systemd.mount-extra=PARTUUID=$partition_id:/run/bunix/medium:vfat:ro,nofail"
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    $with_microcode --initrd=$system_image/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="$command_line $mount_the_stick" \
    --splash=$splash \
    --stub=$stub \
    --output=$kernel_image
# as uki.sh: an image without its microcode starts as well, and no test
# would say
if [ -n "$microcode" ]; then
    if ! grep -a -q kernel/x86/microcode/GenuineIntel.bin $kernel_image; then
        echo "live.sh: the kernel image has no microcode in it" >&2
        exit 1
    fi
fi

# ---- What starts it --------------------------------------------------------------

# The file every EFI starts from a stick: systemd-boot, which starts the
# one kernel image in EFI/Linux, with its menu hidden (as disk.sh)
systemd_boot=$(echo /usr/lib/systemd/boot/efi/systemd-boot*.efi)
[ -f "$systemd_boot" ]
kind=$(basename $systemd_boot .efi)
kind=${kind#systemd-boot}
cp $systemd_boot tree/esp/EFI/BOOT/BOOT${kind^^}.EFI
printf '%s\n' 'timeout 0' 'console-mode keep' 'auto-entries no' > tree/esp/loader/loader.conf

# ---- What bunix-install installs -------------------------------------------------

# This version's files, by the names a release gives them, which
# bunix-install looks for: the three of /usr, its kernel image (as
# disk.sh finds them; the * is the id), and the desktop extension
name=$update/bunix_$version.usr-$partition_architecture
usr_file=$(echo $name.*.raw)
verity_file=$(echo $name-verity.*.raw)
signature_file=$(echo $name-verity-sig.*.raw)
uki=$update/bunix_$version.$partition_architecture.efi
desktop_image=$(echo $desktop/desktop_*.raw)
[ -f "$usr_file" ] && [ -f "$verity_file" ] && [ -f "$signature_file" ] && [ -f "$uki" ] && [ -f "$desktop_image" ]
cp $usr_file $verity_file $signature_file $uki tree/esp/install/
cp $desktop_image tree/esp/install/desktop_$version.$partition_architecture.raw

# the time of each file, which the partition keeps: the build's own would
# make every image another
find tree -exec touch -h -d @$SOURCE_DATE_EPOCH {} +

# ---- The image -------------------------------------------------------------------

# One partition, as large as what is in it and 64 MiB more for the file
# system's own tables: repart's own guess (Minimize=guess) nearly
# doubles it, and the image is downloaded whole.
contents_mib=$(( $(du -sb tree/esp | cut -f1) / 1048576 ))
size_mib=$(( contents_mib + 64 ))
mkdir -p live.d
printf '%s\n' '[Partition]' Type=esp Label=bunix-live UUID=$partition_id Format=vfat CopyFiles=/esp:/ \
    SizeMinBytes=${size_mib}M SizeMaxBytes=${size_mib}M > live.d/00-esp.conf

mkdir -p $out tmp
# as disk.sh: no loop devices, 512-byte sectors, ids that are the same at
# every build
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --sector-size=512 --definitions=live.d --copy-source=/build/tree \
    --seed=$(printf 'bunix live %s' $version | sha256sum | head -c 32) \
    $out/bunix-$partition_architecture-live.img

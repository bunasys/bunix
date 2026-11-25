# Makes the live image of images/live.nix: its kernel image with
# systemd's ukify, then the image itself with systemd-repart, as disk.sh
# makes a disk.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

usr=$system_image/usr-partition
mkdir -p tree/esp/EFI/BOOT tree/esp/EFI/Linux tree/esp/loader tree/esp/install

# This version's files, by the names update.sh gives them (as disk.sh
# finds them; the * is the id)
name=$update/bunix_$version.usr-$partition_architecture
usr_file=$(echo $name.*.raw)
verity_file=$(echo $name-verity.*.raw)
signature_file=$(echo $name-verity-sig.*.raw)
uki=$update/bunix_$version.$partition_architecture.efi
desktop_image=$(echo $desktop/desktop_*.raw)
[ -f "$usr_file" ] && [ -f "$verity_file" ] && [ -f "$signature_file" ] && [ -f "$uki" ] && [ -f "$desktop_image" ]
# the id is what is between the last two dots of a name
id_of() {
    local name=${1%.raw}
    echo ${name##*.}
}

# The stick's ESP, by an id of its own, the same at every build of a
# version and another for every version: what the kernel image's command
# line mounts it by.  Not by its name, which every stick of every version
# has: with two sticks in, or a copy of one on a disk, the other would be
# mounted, its version installed, and this stick offered as a disk to
# install to.
esp_id=$(printf 'bunix live partition %s' $version | sha256sum | head -c 32 \
    | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')

# ---- The kernel image ------------------------------------------------------------

# As uki.sh makes an installed system's, of the same kernel and initrd,
# but for its command line (live.nix), to which /usr's hash is added, as
# there, and the stick's ESP, mounted read-only where bunix-install is
# told to look, as a line of /etc/fstab would have it, which a root in
# memory has none of (systemd.mount-extra).  nofail: without the stick's
# ESP (pulled out, or not found) the system starts all the same.
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)
with_microcode=
if [ -n "$microcode" ]; then
    with_microcode=--microcode=$microcode/usr/lib/microcode/microcode.cpio
fi
kernel_image=tree/esp/EFI/Linux/bunix-live_$version.efi
mount_the_esp="systemd.mount-extra=PARTUUID=$esp_id:/run/bunix/medium:vfat:ro,nofail"
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    $with_microcode --initrd=$initrd/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="usrhash=$(cat $usr/usrhash) $command_line $mount_the_esp" \
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

# ---- What bunix-install installs beside /usr -------------------------------------

# by the names a release gives them, which bunix-install looks for
cp $uki tree/esp/install/
cp $desktop_image tree/esp/install/desktop_$version.$partition_architecture.raw

# the time of each file, which the partition keeps: the build's own would
# make every image another
find tree -exec touch -h -d @$SOURCE_DATE_EPOCH {} +

# ---- The image -------------------------------------------------------------------

partition() {
    local file=$1
    shift
    printf '%s\n' '[Partition]' "$@" > live.d/$file
}
mkdir -p live.d
# The ESP, as large as what is in it and 64 MiB more for the file
# system's own tables: repart's own guess (Minimize=guess) nearly
# doubles it, and the image is downloaded whole
contents_mib=$(( $(du -sb tree/esp | cut -f1) / 1048576 ))
esp_mib=$(( contents_mib + 64 ))
partition 00-esp.conf Type=esp Label=bunix-live UUID=$esp_id Format=vfat CopyFiles=/esp:/ \
    SizeMinBytes=${esp_mib}M SizeMaxBytes=${esp_mib}M
# /usr, as disk.sh puts slot A on a disk: block for block, each partition
# with the id its file is named by (the kernel image's usrhash= finds it
# by them) and the name bunix-install finds it by; each as large as its
# file
partition 10-usr.conf Type=usr Label=bunix_$version \
    UUID=$(id_of $usr_file) CopyBlocks=$usr_file ReadOnly=yes
partition 11-usr-verity.conf Type=usr-verity Label=bunix_${version}_verity \
    UUID=$(id_of $verity_file) CopyBlocks=$verity_file ReadOnly=yes
partition 12-usr-verity-sig.conf Type=usr-verity-sig Label=bunix_${version}_verity_sig \
    UUID=$(id_of $signature_file) CopyBlocks=$signature_file ReadOnly=yes

mkdir -p $out tmp
# as disk.sh: no loop devices, 512-byte sectors, ids that are the same at
# every build
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --sector-size=512 --definitions=live.d --copy-source=/build/tree \
    --seed=$(printf 'bunix live %s' $version | sha256sum | head -c 32) \
    $out/bunix-$partition_architecture-live.img

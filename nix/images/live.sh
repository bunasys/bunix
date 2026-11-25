# Makes the live image of images/live.nix: its kernel image with
# systemd's ukify, then the image itself with systemd-repart, as disk.sh
# makes a disk.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

usr=$system_image/usr-partition
mkdir -p tree/esp/EFI/BOOT tree/esp/EFI/Linux tree/esp/loader tree/esp/install

# ---- The kernel image ------------------------------------------------------------

# As uki.sh makes an installed system's, but for the initramfs, which is
# the whole system and not the initrd that finds /usr on a disk.  No
# usrhash=: there is no /usr to find, and the system in memory has its
# own.
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)
with_microcode=
if [ -n "$microcode" ]; then
    with_microcode=--microcode=$microcode/usr/lib/microcode/microcode.cpio
fi
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    $with_microcode --initrd=$system_image/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="$command_line" \
    --splash=$splash \
    --stub=$stub \
    --output=tree/esp/EFI/Linux/bunix-live_$version.efi

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
# bunix-install looks for: the three of /usr, its kernel image, and the
# desktop extension
cp $update/bunix_${version}.* tree/esp/install/
desktop_image=$(echo $desktop/desktop_*.raw)
[ -f "$desktop_image" ]
cp $desktop_image tree/esp/install/desktop_$version.$partition_architecture.raw
for file in "usr-$partition_architecture.*.raw" "usr-$partition_architecture-verity.*.raw" \
            "usr-$partition_architecture-verity-sig.*.raw" "$partition_architecture.efi"; do
    found=(tree/esp/install/bunix_$version.$file)
    [ -f "${found[0]}" ] || { echo "live.sh: install/ has no bunix_$version.$file" >&2; exit 1; }
done

# the time of each file, which the partition keeps: the build's own would
# make every image another
find tree -exec touch -h -d @$SOURCE_DATE_EPOCH {} +

# ---- The image -------------------------------------------------------------------

# One partition, named as the kernel's command line finds it (live.nix),
# as large as what is in it and 64 MiB more for the file system's own
# tables: repart's own guess (Minimize=guess) nearly doubles it, and the
# image is downloaded whole.
contents_mib=$(( $(du -sb tree/esp | cut -f1) / 1048576 ))
size_mib=$(( contents_mib + 64 ))
mkdir -p live.d
printf '%s\n' '[Partition]' Type=esp Label=bunix-live Format=vfat CopyFiles=/esp:/ \
    SizeMinBytes=${size_mib}M SizeMaxBytes=${size_mib}M > live.d/00-esp.conf

mkdir -p $out tmp
# as disk.sh: no loop devices, 512-byte sectors, ids that are the same at
# every build
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --sector-size=512 --definitions=live.d --copy-source=/build/tree \
    --seed=$(printf 'bunix live %s' $version | sha256sum | head -c 32) \
    $out/bunix-$partition_architecture-live.img

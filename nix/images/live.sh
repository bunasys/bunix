# Makes the live image of images/live.nix with systemd-repart, as disk.sh
# makes a disk: its ESP, with what starts it and the kernel images, and
# /usr's three partitions.
set -euo pipefail
cd /build
export SOURCE_DATE_EPOCH=1728000000

mkdir -p tree/esp/EFI/BOOT tree/esp/EFI/Linux tree/esp/loader tree/esp/install

# This version's files, by the names update.sh gives them (as disk.sh
# finds them; the * is the id)
name=$update/bunix_$version.usr-$partition_architecture
usr_file=$(echo $name.*.raw)
verity_file=$(echo $name-verity.*.raw)
signature_file=$(echo $name-verity-sig.*.raw)
uki=$update/bunix_$version.$partition_architecture.efi
desktop_image=$(echo $desktop/desktop_*.raw)
live_uki=$built_live_kernel_image/bunix-live_$version.efi
[ -f "$usr_file" ] && [ -f "$verity_file" ] && [ -f "$signature_file" ] && [ -f "$uki" ] && [ -f "$desktop_image" ] && [ -f "$live_uki" ]
# The ids of the stick's partitions, which the live kernel image mounts
# them by (live-kernel-image.sh): esp_id, usr_id, verity_id, signature_id
. $built_live_kernel_image/partition-ids

# A release's kernel images, signed for Secure Boot where bunix's key is
# (tools/publish.sh), in place of what was built here unsigned, if they
# are those (check-release-signed.sh).  A test system's were signed in
# their builds, with the development key.
if [ -n "$release_kernel_image" ]; then
    bash $check_release_signed $uki $release_kernel_image
    uki=$release_kernel_image
    bash $check_release_signed $live_uki $release_live_kernel_image
    live_uki=$release_live_kernel_image
fi

# ---- What starts it --------------------------------------------------------------

# The file every EFI starts from a stick, EFI/BOOT/BOOT<kind>.EFI.  On
# x86 that is shim, signed by Microsoft, as a PC's firmware with Secure
# Boot on starts; shim starts grubx64.efi beside it, which is
# systemd-boot, signed with bunix's key, and asks the firmware's keys and
# its own (MOK) about it; and systemd-boot asks shim about each kernel
# image.  Beside them MokManager, which shim starts to enrol a key, and
# the certificate of bunix's, to enrol.  Elsewhere (no Secure Boot):
# systemd-boot itself.  Either way, systemd-boot starts the one kernel
# image in EFI/Linux, with its menu hidden (as disk.sh).
systemd_boot=$(echo /usr/lib/systemd/boot/efi/systemd-boot*.efi)
[ -f "$systemd_boot" ]
kind=$(basename $systemd_boot .efi)
kind=${kind#systemd-boot}
default_loader=tree/esp/EFI/BOOT/BOOT${kind^^}.EFI
if [ -n "$shim" ]; then
    cp $shim/usr/lib/shim/shim$kind.efi $default_loader
    cp $shim/usr/lib/shim/mm$kind.efi tree/esp/EFI/BOOT/
    cp $signed_loader/usr/lib/systemd/boot/efi/systemd-boot$kind.efi.signed tree/esp/EFI/BOOT/grub$kind.efi
    cp $signed_loader/usr/share/bunix/secure-boot.cer tree/esp/bunix.cer
else
    cp $systemd_boot $default_loader
fi
printf '%s\n' 'timeout 0' 'console-mode keep' 'auto-entries no' > tree/esp/loader/loader.conf

# A test machine with Secure Boot (live.nix: secureBootEnrolment): its
# firmware has no keys yet and starts anything; systemd-boot gives it
# Microsoft's and the development key from loader/keys/auto and restarts
# the machine, which then starts only what they signed (as disk.sh)
if [ -n "$secure_boot_enrolment" ]; then
    mkdir -p tree/esp/loader/keys/auto
    cp $secure_boot_enrolment/*.auth tree/esp/loader/keys/auto/
    echo 'secure-boot-enroll force' >> tree/esp/loader/loader.conf
fi

cp $live_uki tree/esp/EFI/Linux/bunix-live_$version.efi

# ---- What bunix-install installs beside /usr -------------------------------------

# by the names a release gives them, which bunix-install looks for
cp $uki tree/esp/install/bunix_$version.$partition_architecture.efi
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
# system's own tables: repart's own guess (Minimize=guess) nearly doubles
# it, and the image is downloaded whole
contents_mib=$(( $(du -sb tree/esp | cut -f1) / 1048576 ))
esp_mib=$(( contents_mib + 64 ))
partition 00-esp.conf Type=esp Label=bunix-live UUID=$esp_id Format=vfat CopyFiles=/esp:/ \
    SizeMinBytes=${esp_mib}M SizeMaxBytes=${esp_mib}M
# /usr, as disk.sh puts slot A on a disk, block for block, each partition
# by the name bunix-install finds it by, but by the stick's own ids (not
# the ones an installed disk's slot A has: live-kernel-image.sh says why);
# each as large as its file
partition 10-usr.conf Type=usr Label=bunix_$version \
    UUID=$usr_id CopyBlocks=$usr_file ReadOnly=yes
partition 11-usr-verity.conf Type=usr-verity Label=bunix_${version}_verity \
    UUID=$verity_id CopyBlocks=$verity_file ReadOnly=yes
partition 12-usr-verity-sig.conf Type=usr-verity-sig Label=bunix_${version}_verity_sig \
    UUID=$signature_id CopyBlocks=$signature_file ReadOnly=yes

mkdir -p $out tmp
# as disk.sh: no loop devices, 512-byte sectors, ids that are the same at
# every build
TMPDIR=/build/tmp systemd-repart --empty=create --size=auto --dry-run=no --offline=yes \
    --sector-size=512 --definitions=live.d --copy-source=/build/tree \
    --seed=$(printf 'bunix live %s' $version | sha256sum | head -c 32) \
    $out/bunix-$partition_architecture-live.img

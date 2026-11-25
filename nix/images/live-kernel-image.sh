# Makes the live kernel image of images/live.nix with systemd's ukify, as
# uki.sh makes an installed system's, of the same kernel and initrd but
# for its command line; and signs it for Secure Boot with the
# development key, where it is a test system's on x86 ($sign_here).
set -euo pipefail
cd /build

usr=$system_image/usr-partition

# an id made of the words given, with the dashes an id is written with
id_of_words() {
    printf '%s' "$*" | sha256sum | head -c 32 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
}

# The stick's ESP, by an id of its own, the same at every build of a
# version and another for every version: what the command line mounts it
# by (live.sh gives the ESP the same).  Not by its name, which every
# stick of every version has: with two sticks in, or a copy of one on a
# disk, the other would be mounted, its version installed, and this
# stick offered as a disk to install to.  Mounted read-only where
# bunix-install is told to look, as a line of /etc/fstab would have it,
# which a root in memory has none of (systemd.mount-extra).  nofail:
# without it (pulled out, or not found) the system starts all the same.
esp_id=$(id_of_words bunix live partition $version)
mount_the_esp="systemd.mount-extra=PARTUUID=$esp_id:/run/bunix/medium:vfat:ro,nofail"

# /usr's partitions on the stick, by ids of their own too, named on the
# command line (systemd.verity_usr_data=, _hash=), and not by those the
# hash makes (images/update.sh), which an installed disk's slot A has:
# with the stick in, an installed system would take whichever of the two
# udev saw last for its /usr, and end when the stick is pulled out; and
# the live system, on a machine with this version installed, might run
# the disk's, which the installer is to replace.  dm-verity checks either
# against the hash; the ids say which disk.
usrhash=$(cat $usr/usrhash)
usr_id=$(id_of_words bunix live usr $usrhash)
verity_id=$(id_of_words bunix live usr-verity $usrhash)
signature_id=$(id_of_words bunix live usr-verity-sig $usrhash)
use_the_sticks_usr="systemd.verity_usr_data=PARTUUID=$usr_id systemd.verity_usr_hash=PARTUUID=$verity_id"

stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)
with_microcode=
if [ -n "$microcode" ]; then
    with_microcode=--microcode=$microcode/usr/lib/microcode/microcode.cpio
fi
mkdir -p $out unsigned
image=$out/bunix-live_$version.efi
# made here first, where it is to be signed
made=$image
if [ -n "$sign_here" ]; then
    made=unsigned/$(basename $image)
fi
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    $with_microcode --initrd=$initrd/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="usrhash=$usrhash $use_the_sticks_usr $command_line $mount_the_esp" \
    --splash=$splash \
    --stub=$stub \
    --output=$made
# as uki.sh: an image without its microcode starts as well, and no test
# would say
if [ -n "$microcode" ]; then
    if ! grep -a -q kernel/x86/microcode/GenuineIntel.bin $made; then
        echo "live-kernel-image.sh: the kernel image has no microcode in it" >&2
        exit 1
    fi
fi
if [ -n "$sign_here" ]; then
    BUNIX_SECURE_BOOT_KEY_FILE=$development_key BUNIX_SECURE_BOOT_CERTIFICATE=$development_certificate \
        bash $sign_kernel_image $made $image
fi
# the ids live.sh gives the stick's partitions
printf '%s\n' "esp_id=$esp_id" "usr_id=$usr_id" "verity_id=$verity_id" "signature_id=$signature_id" > $out/partition-ids

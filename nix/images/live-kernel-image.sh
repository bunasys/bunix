# Makes the live kernel image of images/live.nix with systemd's ukify, as
# uki.sh makes an installed system's, of the same kernel and initrd but
# for its command line; and signs it for Secure Boot with the
# development key, where it is a test system's on x86 ($sign_here).
set -euo pipefail
cd /build

usr=$system_image/usr-partition

# The stick's ESP, by an id of its own, the same at every build of a
# version and another for every version: what the command line mounts it
# by (live.sh gives the ESP the same).  Not by its name, which every
# stick of every version has: with two sticks in, or a copy of one on a
# disk, the other would be mounted, its version installed, and this
# stick offered as a disk to install to.  Mounted read-only where
# bunix-install is told to look, as a line of /etc/fstab would have it,
# which a root in memory has none of (systemd.mount-extra).  nofail:
# without it (pulled out, or not found) the system starts all the same.
esp_id=$(printf 'bunix live partition %s' $version | sha256sum | head -c 32 \
    | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/')
mount_the_esp="systemd.mount-extra=PARTUUID=$esp_id:/run/bunix/medium:vfat:ro,nofail"

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
    --cmdline="usrhash=$(cat $usr/usrhash) $command_line $mount_the_esp" \
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
# what live.sh gives the ESP
echo $esp_id > $out/esp-id

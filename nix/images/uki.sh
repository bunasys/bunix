# Makes the unified kernel image of images/uki.nix with systemd's ukify.
set -euo pipefail
cd /build

usr=$system_image/usr-partition
# the stub is named after the machine's kind of EFI (aa64, x64)
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)

# The kernel is the one the system's build had (image.sh), so that it is
# of the same build as the modules in that /usr.
#
# Of the element, not here: microcode (x86's), the splash (no Plymouth),
# and the signature (uki.nix).
mkdir -p $out
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    --initrd=$initrd/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="usrhash=$(cat $usr/usrhash) $command_line" \
    --stub=$stub \
    --output=$out/bunix_$(cat $usr/version).efi

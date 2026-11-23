# Makes the unified kernel image of images/uki.nix with systemd's ukify.
set -euo pipefail
cd /build

usr=$system_image/usr-partition
# the stub is named after the machine's kind of EFI (aa64, x64)
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)

# The kernel is the one the system's build had (image.sh), so that it is
# of the same build as the modules in that /usr.
#
# Of the element, not here: the signature (uki.nix).

with_microcode=
if [ -n "$microcode" ]; then
    with_microcode=--microcode=$microcode/usr/lib/microcode/microcode.cpio
fi
mkdir -p $out
image=$out/bunix_$(cat $usr/version).efi
python3 /usr/lib/systemd/ukify build \
    --linux=$usr/vmlinuz --uname=$(cat $usr/kernel-release) \
    $with_microcode --initrd=$initrd/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="usrhash=$(cat $usr/usrhash) $command_line" \
    --splash=$splash \
    --stub=$stub \
    --output=$image

# An image made without its microcode starts as well as one with it, and
# no test would say.  The archive is not compressed, and names its files.
if [ -n "$microcode" ]; then
    if ! grep -a -q kernel/x86/microcode/GenuineIntel.bin $image; then
        echo "uki.sh: the kernel image has no microcode in it" >&2
        exit 1
    fi
fi

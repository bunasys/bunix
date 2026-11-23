# Makes the unified kernel image of images/uki.nix with systemd's ukify.
set -euo pipefail
cd /build

usr=$system_image/usr-partition
# the kernel is in a directory named after its release
modules=$(echo $linux/usr/lib/modules/*)
release=$(basename $modules)
# the stub is named after the machine's kind of EFI (aa64, x64)
stub=$(echo /usr/lib/systemd/boot/efi/linux*.efi.stub)

# Of the element, not here: microcode (x86's), the splash (no Plymouth),
# the signature (uki.nix), and the check that the kernel and /usr's
# modules are of one build: this /usr has no modules yet, and both are
# made of the one boot.linux.
mkdir -p $out
python3 /usr/lib/systemd/ukify build \
    --linux=$modules/vmlinuz --uname=$release \
    --initrd=$initrd/initramfs.cpio.gz \
    --os-release=@$usr/os-release \
    --cmdline="usrhash=$(cat $usr/usrhash) $command_line" \
    --stub=$stub \
    --output=$out/bunix_$(cat $usr/version).efi

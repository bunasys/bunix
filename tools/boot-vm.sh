#!/bin/sh
# Boots bunix in a virtual machine on an Apple Silicon Mac: the kernel and
# the initramfs are built in the builder VM (tools/nix-builder/lima.yaml),
# copied out of its store, and run by QEMU with the Mac's own hypervisor.
#
#   tools/boot-vm.sh          a shell on the console; Ctrl-a x leaves
#   tools/boot-vm.sh demo     boots, says what booted, powers off
#
# Needs: limactl with the bunix-builder VM, and qemu-system-aarch64.
set -eu

build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link | tail -n 1
}
kernel=$(build /bunix/nix/packages.nix -A linux)
initramfs=$(build /bunix/nix/initramfs.nix)

boot=${TMPDIR:-/tmp}/bunix-boot
mkdir -p "$boot"
limactl copy "bunix-builder:$kernel/Image" "$boot/Image"
limactl copy "bunix-builder:$initramfs" "$boot/initramfs.cpio.gz"

# -accel hvf: the Mac's hypervisor; the guest runs on the real processor
# console=ttyAMA0: the kernel's messages and the shell on QEMU's serial
#   port, which -nographic connects to this terminal
exec qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 2G \
    -kernel "$boot/Image" -initrd "$boot/initramfs.cpio.gz" \
    -append "console=ttyAMA0 quiet $*" -nographic -no-reboot

#!/bin/sh
# Boots bunix in a virtual machine on an Apple Silicon Mac: the kernel and
# the initramfs are built in the builder (the Lima VM of
# tools/nix-builder/lima.yaml), copied out of its store, and run by QEMU
# with the Mac's own hypervisor.
#
#   tools/boot-vm.sh          a shell on the console; `exit` powers off,
#                             Ctrl-a x leaves at once
#   tools/boot-vm.sh demo     boots, says what booted, powers off
#
# Needs: limactl with the bunix-builder VM, and qemu-system-aarch64.
set -eu

# nix-build prints the store path of what it built, and nothing else, on
# its standard output.  No pipe after it: a failed build has to stop this
# script.
build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link
}
kernel=$(build /bunix/nix/packages.nix -A linux)
initramfs=$(build /bunix/nix/initramfs.nix)

boot=${TMPDIR:-/tmp}/bunix-boot
mkdir -p "$boot"
limactl copy "bunix-builder:$kernel/vmlinuz" "$boot/vmlinuz"
limactl copy "bunix-builder:$initramfs" "$boot/initramfs.cpio.gz"

# -accel hvf: the Mac's hypervisor; the guest runs on the real processor
# console=ttyAMA0: the kernel's messages and the shell on QEMU's serial
#   port, which -nographic connects to this terminal
exec qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 2G \
    -kernel "$boot/vmlinuz" -initrd "$boot/initramfs.cpio.gz" \
    -append "console=ttyAMA0 quiet $*" -nographic -no-reboot

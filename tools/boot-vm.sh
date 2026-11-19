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
# While it runs, `ssh -p 2022 root@127.0.0.1` logs in (see below).
#   BUNIX_SSH_KEY     the public key that may; default ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT    the Mac's port for it; default 2022
#
# Needs: limactl with the bunix-builder VM, and qemu-system-aarch64.
set -eu

# nix-build prints the store path of what it built, and nothing else, on
# its standard output.  No pipe after it: a failed build has to stop this
# script.
build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link
}
kernel=$(build /bunix/nix/boot.nix -A linux)
initramfs=$(build /bunix/nix/images/initramfs.nix)
# the kernel is in a directory named after its release
vmlinuz=$(limactl shell bunix-builder sh -c "echo $kernel/usr/lib/modules/*/vmlinuz")

boot=${TMPDIR:-/tmp}/bunix-boot
mkdir -p "$boot"
# Not over the copies of the last run: every file of the store has the
# same date, and a copy is skipped when the date and the size are what
# they were, as a kernel image's size is from build to build.
rm -f "$boot/vmlinuz" "$boot/initramfs.cpio.gz"
limactl copy "bunix-builder:$vmlinuz" "$boot/vmlinuz"
limactl copy "bunix-builder:$initramfs/initramfs.cpio.gz" "$boot/initramfs.cpio.gz"

# A network card behind QEMU's own small network, which gives the guest
# an address by DHCP.  The Mac's port 2222 is the guest's SSH port:
#
#   ssh -p 2022 -o UserKnownHostsFile=/dev/null root@127.0.0.1
#
# (no known_hosts: the guest makes new host keys at every boot).  The key
# that may log in is this user's, given on the kernel's command line.
ssh_port=${BUNIX_SSH_PORT:-2022}
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}

authorized_key=
key_type=
key=
# `|| true`: read fails on a last line without a newline, having read it
[ ! -f "$public_key_file" ] || read -r key_type key _ < "$public_key_file" || true
case $key_type in
    ssh-*|ecdsa-*|sk-*) authorized_key="authorized_key=$key_type:$key" ;;
    *) echo "boot-vm.sh: no public key in $public_key_file (a line \"<type> <key>\"); the guest will not start sshd" >&2 ;;
esac

# -accel hvf: the Mac's hypervisor; the guest runs on the real processor
# console=ttyAMA0: the kernel's messages and the shell on QEMU's serial
#   port, which -nographic connects to this terminal
exec qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 2G \
    -kernel "$boot/vmlinuz" -initrd "$boot/initramfs.cpio.gz" \
    -netdev user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22 -device virtio-net-pci,netdev=net \
    -append "console=ttyAMA0 quiet $authorized_key $*" -nographic -no-reboot

#!/bin/sh
# Boots bunix in a virtual machine on an Apple Silicon Mac: the kernel and
# the image are built in the builder (the Lima VM of
# tools/nix-builder/lima.yaml), copied out of its store, and run by QEMU
# with the Mac's own hypervisor.
#
#   tools/boot-vm.sh [disk] [check] [words for the kernel's command line]
#
#   (neither)   the whole system in memory; root's shell on the console.
#               `poweroff` ends it, Ctrl-a x leaves at once.
#   disk        the system installed on a disk (nix/images/disk.nix): /usr
#               read-only from its partition, checked against its hash,
#               and a root partition that keeps what is written.  The
#               disk is a new copy at every run.
#   check       boots, asks systemd over SSH whether all of it started,
#               says so and powers off: for a boot that nobody is
#               watching.  Fails if a unit failed.
#
# While it runs, `ssh -p 2022 root@127.0.0.1` logs in (see below).
#   BUNIX_SIGNATURE   with disk: the signature of a system for release, a
#                     file in the repository (tools/sign.sh has the
#                     steps); the disk is then of that system
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
# the two words, in either order, before any for the kernel
on_disk=
check=
while [ $# -gt 0 ]; do
    case $1 in
        disk) on_disk=yes ;;
        check) check=yes ;;
        *) break ;;
    esac
    shift
done

kernel=$(build /bunix/nix/boot.nix -A linux)
if [ -n "$on_disk" ]; then
    # what the machine starts from, in memory, and the disk it finds the
    # rest on
    image=$(build /bunix/nix/images/initrd.nix)
    # a disk with no signature given is a test system's (images/disk.nix)
    if [ -n "${BUNIX_SIGNATURE:-}" ]; then
        disk=$(build /bunix/nix/images/disk.nix --arg signature "/bunix/$BUNIX_SIGNATURE")
    else
        disk=$(build /bunix/nix/images/disk.nix)
    fi
else
    image=$(build /bunix/nix/images/system.nix)
fi
# the kernel is in a directory named after its release
vmlinuz=$(limactl shell bunix-builder sh -c "echo $kernel/usr/lib/modules/*/vmlinuz")

boot=${TMPDIR:-/tmp}/bunix-boot
mkdir -p "$boot"
# Not over the copies of the last run: every file of the store has the
# same date, and a copy is skipped when the date and the size are what
# they were, as a kernel image's size is from build to build.
rm -f "$boot/vmlinuz" "$boot/initramfs.cpio.gz"
limactl copy "bunix-builder:$vmlinuz" "$boot/vmlinuz"
limactl copy "bunix-builder:$image/initramfs.cpio.gz" "$boot/initramfs.cpio.gz"

# usrhash=: the one /usr this kernel will run, by the hash of its image;
#   systemd finds the partitions by it.
# mount.usrfstype=: said, so that nothing tries to check and repair a file
#   system that is read-only and checked block by block.
# root=: the partition that is the root, by its name.
disk_arguments=
disk_words=
if [ -n "$on_disk" ]; then
    rm -f "$boot/disk.raw"
    limactl copy "bunix-builder:$disk/disk.raw" "$boot/disk.raw"
    # copied out of the store, where nothing can be written
    chmod u+w "$boot/disk.raw"
    usrhash=$(limactl shell bunix-builder cat "$disk/usrhash")
    disk_arguments="-drive file=$boot/disk.raw,format=raw,if=virtio"
    disk_words="usrhash=$usrhash mount.usrfstype=erofs mount.usrflags=ro root=PARTLABEL=bunix-root rw"
fi

# A network card behind QEMU's own small network, which gives the guest
# an address by DHCP.  The Mac's port 2022 is the guest's SSH port:
#
#   ssh -p 2022 -o UserKnownHostsFile=/dev/null root@127.0.0.1
#
# (no known_hosts: the guest makes new host keys at every boot).
ssh_port=${BUNIX_SSH_PORT:-2022}
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}

# The key that may log in is this user's, given on the kernel's command
# line as what systemd calls a credential, which sshd's unit takes
# (images/system/.../sshd.service).  In base64, since the command line cannot
# carry the spaces of a key's line.
authorized_keys=
if [ -f "$public_key_file" ]; then
    authorized_keys="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
else
    echo "boot-vm.sh: no public key in $public_key_file; nobody can log in over SSH" >&2
fi

# -accel hvf: the Mac's hypervisor; the guest runs on the real processor
# console=ttyAMA0: the kernel's and systemd's messages, and root's shell,
#   on QEMU's serial port, which -nographic connects to this terminal
run_qemu() {
    exec qemu-system-aarch64 -M virt -accel hvf -cpu host -smp 4 -m 4G \
        -kernel "$boot/vmlinuz" -initrd "$boot/initramfs.cpio.gz" \
        -netdev user,id=net,hostfwd=tcp:127.0.0.1:$ssh_port-:22 -device virtio-net-pci,netdev=net \
        $disk_arguments \
        -append "console=ttyAMA0 $disk_words $authorized_keys $*" -nographic -no-reboot
}

if [ -z "$check" ]; then
    run_qemu "$@"
fi

# check: the machine runs behind this script, and is asked how it is.
if [ -z "$authorized_keys" ]; then
    echo "boot-vm.sh: check asks over SSH, and has no key to log in with" >&2
    exit 1
fi
run_qemu quiet "$@" < /dev/null > "$boot/console.log" 2>&1 &
qemu=$!
# however this script ends, the machine does not stay behind it, holding
# the port for the next one
trap 'kill $qemu 2> /dev/null || true' EXIT

in_guest() {
    ssh -p "$ssh_port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 -o LogLevel=ERROR root@127.0.0.1 "$@"
}
# about a minute
tries_left=30
until in_guest true 2> /dev/null; do
    tries_left=$((tries_left - 1))
    # kill -0: is it still there?  It ends at once if the port is taken.
    if [ $tries_left = 0 ] || ! kill -0 $qemu 2> /dev/null; then
        echo "boot-vm.sh: the guest did not answer on SSH; its console is in $boot/console.log" >&2
        exit 1
    fi
    sleep 2
done
# --wait: until systemd has started everything, or given up on some of it.
# `|| true`: it fails for every state but running, and the state is judged
# below.
state=$(in_guest systemctl is-system-running --wait || true)
in_guest 'uname -srm; systemctl --no-pager --failed' || true
echo "systemd: $state"
in_guest systemctl poweroff || true
wait $qemu || true
[ "$state" = running ]

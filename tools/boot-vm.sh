#!/bin/sh
# Boots bunix in a virtual machine, from an Apple Silicon Mac: the kernel
# and the image are built in the builder (the Lima VM of
# tools/nix-builder/lima.yaml), copied out of its store, and run by QEMU
# with the Mac's own hypervisor.  Or, with BUNIX_ARCHITECTURE=x86_64,
# built and run on the x86_64 builder (tools/test-machine.sh says how).
#
#   tools/boot-vm.sh [disk] [check] [words for the kernel's command line]
#
#   (neither)   the whole system in memory; root's shell on the console.
#               `poweroff` ends it, Ctrl-a x leaves at once.
#   disk        the system installed on a disk (nix/images/disk.nix),
#               started as a machine with EFI starts it: systemd-boot,
#               the unified kernel image, /usr read-only from its
#               partition and checked against its hash, and a root
#               partition, made at the first boot, that keeps what is
#               written.  The disk is a new copy at every run.
#   check       boots, asks systemd over SSH whether all of it started,
#               says so and powers off: for a boot that nobody is
#               watching.  Fails if a unit failed, or if nothing keeps
#               the clock by the network's.
#
# While it runs, `ssh -p 2022 root@127.0.0.1` logs in (see below).
#   BUNIX_ARCHITECTURE, BUNIX_X86_BUILDER
#                     tools/test-machine.sh
#   BUNIX_SIGNATURE   with disk: the signature of a system for release, a
#                     file in the repository (tools/sign.sh has the
#                     steps); the disk is then of that system
#   BUNIX_CHECK_SCRIPT
#                     with check: one script to run on the machine as
#                     well, as root, by bash (tools/vm-checks/).  The
#                     check fails if it does, or if it leaves a unit
#                     failed.
#   BUNIX_SSH_KEY     the public key that may; default ~/.ssh/id_ed25519.pub
#   BUNIX_SSH_PORT    the Mac's port for it; default 2022
#   BUNIX_MONITOR     set, to look at the machine's screen: QEMU's
#                     monitor is then a socket where QEMU runs
#                     (tools/test-machine.sh: run_qemu)
#
# Needs: limactl with the bunix-builder VM, and qemu-system-aarch64 with
# the EFI firmware that comes with it (share/qemu/edk2-aarch64-code.fd);
# or, for x86_64, ssh to its builder.
set -eu

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

# said now, and not after a build and a boot
check_script=${BUNIX_CHECK_SCRIPT:-}
if [ -n "$check_script" ] && [ -z "$check" ]; then
    echo "boot-vm.sh: BUNIX_CHECK_SCRIPT is for check" >&2
    exit 1
fi
if [ -n "$check_script" ] && [ ! -f "$check_script" ]; then
    echo "boot-vm.sh: no script $check_script" >&2
    exit 1
fi

ssh_port=${BUNIX_SSH_PORT:-2022}
tool=boot-vm.sh
. "$(dirname "$0")/test-machine.sh"
# The x86_64 builder is sent what git has of the working tree, and a
# signature is not of that (tools/sign.sh leaves it in out/).
if [ -n "${BUNIX_SIGNATURE:-}" ] && [ "$architecture" != aarch64 ]; then
    echo "boot-vm.sh: BUNIX_SIGNATURE is for aarch64 so far" >&2
    exit 1
fi
prepare_machine

if [ -n "$on_disk" ]; then
    # Small slots: less to copy out of the builder.  A disk with no
    # signature given is a test system's (images/disk.nix).
    if [ -n "${BUNIX_SIGNATURE:-}" ]; then
        disk=$(build "$source/nix/images/disk.nix" --argstr espSize 512M \
            --argstr usrSlotSize 512M --argstr usrVeritySize 8M \
            --arg signature "$source/$BUNIX_SIGNATURE")
    else
        disk=$(build "$source/nix/images/disk.nix" --argstr espSize 512M \
            --argstr usrSlotSize 512M --argstr usrVeritySize 8M)
    fi
    copy_built_file_to_machine "$disk/disk.raw" disk.raw
    # with room after its partitions for the root partition the first
    # boot makes
    in_machine_directory "truncate -s +2G disk.raw"
else
    image=$(build "$source/nix/images/system.nix")
    # the kernel the system was built with: its modules are in the image
    copy_built_file_to_machine "$image/usr-partition/vmlinuz" vmlinuz
    copy_built_file_to_machine "$image/initramfs.cpio.gz" initramfs.cpio.gz
fi

# A network card behind QEMU's own small network, which gives the guest
# an address by DHCP.  The Mac's port 2022 is the guest's SSH port:
#
#   ssh -p 2022 -o UserKnownHostsFile=/dev/null root@127.0.0.1
#
# (no known_hosts: the guest makes new host keys at every boot).
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}

# The key that may log in is this user's, given on the kernel's command
# line as what systemd calls a credential, which sshd's unit takes
# (images/system/.../sshd.service).  In base64: a key's line has spaces.
key_word=
if [ -f "$public_key_file" ]; then
    key_word="systemd.set_credential_binary=bunix.authorized_keys:$(base64 < "$public_key_file" | tr -d '\n')"
else
    echo "boot-vm.sh: no public key in $public_key_file; nobody can log in over SSH" >&2
fi

# boot_by <run_qemu|start_qemu> [words for the kernel's command line]:
# the machine at this terminal, or behind this script
# (tools/test-machine.sh).
#
# console=: the kernel's and systemd's messages, and root's shell, on
#   the serial port, which is QEMU's own input and output.
#
# In memory, QEMU itself starts the kernel, and gives it its command line.
# On a disk, QEMU starts EFI firmware (the one that comes with it), which
# finds systemd-boot on the disk; the command line is in the kernel
# image, and the words here are added to it the way a machine's firmware
# hands such things over (SMBIOS).
boot_by() {
    run_or_start=$1
    shift
    kernel_words="console=$console $key_word $*"
    # shellcheck disable=SC2086  # QEMU's words are several each
    if [ -z "$on_disk" ]; then
        $run_or_start $machine_on_real_processor -kernel "$machine_directory/vmlinuz" \
            -initrd "$machine_directory/initramfs.cpio.gz" -append "$kernel_words"
        return
    fi
    # QEMU reads a single comma as the end of the value
    smbios_words=$(printf %s "$kernel_words" | sed 's/,/,,/g')
    # shellcheck disable=SC2086
    $run_or_start $machine_on_real_processor $efi_firmware \
        -drive "file=$machine_directory/disk.raw,format=raw,if=virtio" \
        -smbios "type=11,value=io.systemd.stub.kernel-cmdline-extra=$smbios_words"
}

# (run_qemu does not come back)
if [ -z "$check" ]; then
    boot_by run_qemu "$@"
fi

# check: the machine runs behind this script, and is asked how it is.
if [ -z "$key_word" ]; then
    echo "boot-vm.sh: check asks over SSH, and has no key to log in with" >&2
    exit 1
fi
boot_by start_qemu quiet "$@"
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
        echo "boot-vm.sh: the guest did not answer on SSH; its console is in $work/console.log" >&2
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
# The clock: a machine with none of its own starts before every signature
# was made, and takes no update until the network has told it the time
# (docs/nix-usr-system.md).  A system where nothing asks for the time
# would start all the same, so this is asked apart.
timesync=$(in_guest systemctl is-active systemd-timesyncd.service || true)
echo "systemd-timesyncd: $timesync"
script=passed
if [ -n "$check_script" ]; then
    # As a file there, not read by bash from this connection: a command
    # of the script that reads its input would read the rest of the
    # script, and bash, finding no more, would end as if all had passed.
    in_guest 'cat > /run/check-script.sh && bash /run/check-script.sh < /dev/null' \
        < "$check_script" || script=failed
    echo "$check_script: $script"
    # Asked again: what the script did may have failed a unit that it
    # did not look at (the manager of a user's own services, say).
    state=$(in_guest systemctl is-system-running || true)
    in_guest systemctl --no-pager --failed || true
    echo "systemd, after the script: $state"
fi
in_guest systemctl poweroff || true
wait $qemu || true
[ "$state" = running ]
[ "$timesync" = active ]
[ "$script" = passed ]

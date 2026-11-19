#!/bin/sh
# Boots bunix on an Apple Silicon Mac, from this Mac, over a USB-C cable.
# The system is loaded into the other Mac's memory, and gone when it is
# turned off.  Its disk is left alone, but for a partition named
# bunix-root, if it has one: /init keeps /var, /home and /root there.
#
#   tools/boot-mac.sh <device tree> [words for the kernel's command line]
#   tools/boot-mac.sh t8103-j293        a 13-inch MacBook Pro M1
#
# The other Mac has to be waiting for this one: showing the screen of a
# boot loader in proxy mode (Asahi's m1n1 is the one tried), with the
# cable in.  docs/nix-usr-system.md says how a Mac gets there.
#
# What this does: builds the kernel, the image and aura in the builder
# (tools/nix-builder/lima.yaml) and copies them out; has the waiting boot
# loader start aura; has aura start the kernel with the Mac's device tree
# and the image.  The console is then on the Mac's own screen and
# keyboard, and, once it is on a network, `ssh root@<its address>`.
#
#   BUNIX_SSH_KEY     the public key that may log in; default
#                     ~/.ssh/id_ed25519.pub
#   BUNIX_FIRMWARE    an archive of that Mac's own firmware (a cpio with
#                     /vendorfw in it, made from its macOS), put before the
#                     image.  Without it the Mac has no Wi-Fi.
#   AURADEVICE        the boot loader's serial port, if it is not found
#
# Needs: limactl with the bunix-builder VM, and python3.  aura's tools are
# Python and need two modules, which are installed into a directory of
# their own beside the copied files, from the network, the first time.
set -eu

device_tree=${1:?usage: boot-mac.sh <device tree, as t8103-j293> [kernel words]}
shift

# nix-build prints the store path of what it built, and nothing else, on
# its standard output.  No pipe after it: a failed build has to stop this
# script.
build() {
    limactl shell bunix-builder nix-build "$@" --no-out-link
}
kernel=$(build /bunix/nix/boot.nix -A linux)
aura=$(build /bunix/nix/boot.nix -A aura)
initramfs=$(build /bunix/nix/images/initramfs.nix)
# the kernel is in a directory named after its release
modules=$(limactl shell bunix-builder sh -c "echo $kernel/usr/lib/modules/*")

boot=${TMPDIR:-/tmp}/bunix-boot-mac
mkdir -p "$boot"
# Not over the copies of the last run: every file of the store has the
# same date, and a copy is skipped when the date and the size are what
# they were, as a kernel image's size is from build to build.
rm -f "$boot/Image" "$boot/device-tree.dtb" "$boot/initramfs.cpio.gz"
limactl copy "bunix-builder:$modules/vmlinuz" "$boot/Image"
limactl copy "bunix-builder:$modules/dtb/apple/$device_tree.dtb" "$boot/device-tree.dtb"
limactl copy "bunix-builder:$initramfs/initramfs.cpio.gz" "$boot/initramfs.cpio.gz"
# A copy out of the store is read-only, as the store is; so is one left
# by a run that was interrupted.
[ ! -d "$boot/aura" ] || chmod -R u+w "$boot/aura"
rm -rf "$boot/aura"
limactl copy -r "bunix-builder:$aura/usr/lib/aura" "$boot/aura"
chmod -R u+w "$boot/aura"
[ -f "$boot/aura/chainload-stub.bin" ]

# Asked whether the modules load, not whether the directory is there: an
# install that failed half-way leaves the directory.
python=$boot/python/bin/python
if ! "$python" -c 'import serial, construct' 2> /dev/null; then
    rm -rf "$boot/python"
    python3 -m venv "$boot/python"
    "$python" -m pip install --quiet pyserial==3.5 construct==2.10.70
fi

# The kernel takes an initramfs in several archives, one after the other.
# The firmware's is not compressed, and has to come first.
image=$boot/initramfs.cpio.gz
firmware_words=
if [ -n "${BUNIX_FIRMWARE:-}" ]; then
    image=$boot/initramfs-with-firmware
    cat "$BUNIX_FIRMWARE" "$boot/initramfs.cpio.gz" > "$image"
    firmware_words=firmware_class.path=/vendorfw
fi

# as tools/boot-vm.sh: the key is given on the kernel's command line
public_key_file=${BUNIX_SSH_KEY:-$HOME/.ssh/id_ed25519.pub}
authorized_key=
key_type=
key=
[ ! -f "$public_key_file" ] || read -r key_type key _ < "$public_key_file" || true
case $key_type in
    ssh-*|ecdsa-*|sk-*) authorized_key="authorized_key=$key_type:$key" ;;
    *) echo "boot-mac.sh: no public key in $public_key_file (a line \"<type> <key>\"); the Mac will not start sshd" >&2 ;;
esac

# The boot loader is two serial ports, named after the Mac's serial
# number and ending in 1 and 3; the first is the one to talk to.  Other
# things are serial ports too: with more than one candidate, the choice
# is the caller's.
if [ -z "${AURADEVICE:-}" ]; then
    candidates=$(ls /dev/cu.usbmodem*1 2> /dev/null || true)
    case $candidates in
        "") echo "boot-mac.sh: no boot loader is waiting on USB (no /dev/cu.usbmodem...1)" >&2; exit 1 ;;
        *"
"*) echo "boot-mac.sh: more than one candidate; name one in AURADEVICE:" >&2; echo "$candidates" >&2; exit 1 ;;
    esac
    AURADEVICE=$candidates
fi
export AURADEVICE

# --stub: the few instructions that start aura, assembled when aura was
#   built; this Mac has no assembler for them.
"$python" "$boot/aura/proxyclient/tools/chainload.py" \
    --stub "$boot/aura/chainload-stub.bin" "$boot/aura/aura.macho"

# --compression none: the kernel image is not compressed.
# --capture: where what aura says while it hands over is kept; without it
#   the tool wants a terminal to stay on, and the port is gone the moment
#   the kernel takes it.
# console=tty0 last: /init's messages and its shell are on the Mac's
#   screen; the serial console before it is for a debug cable.
"$python" "$boot/aura/proxyclient/tools/linux.py" --compression none \
    --capture "$boot/handover.log" --capture-seconds 3 \
    -b "console=ttySAC0,1500000 console=tty0 $authorized_key $firmware_words $*" \
    "$boot/Image" "$boot/device-tree.dtb" "$image" ||
    echo "boot-mac.sh: the tool ended with an error; if its last words were \"Ready to boot\", the port went away under it, as it does" >&2

echo "boot-mac.sh: look at the Mac's screen"

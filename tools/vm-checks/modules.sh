# The kernel's modules on a running bunix: run on it, as root, by
#
#   BUNIX_ARCHITECTURE=x86_64 BUNIX_CHECK_SCRIPT=tools/vm-checks/modules.sh tools/boot-vm.sh disk check
#
# For x86_64, whose kernel has its drivers for a PC's hardware as modules
# (nix/boot/linux/x86_64.config).  An arm64 system has none, and passes
# with nothing checked.
#
# udev loaded a driver for a device of the machine.  One module,
# WireGuard's, is refused with a byte changed and refused without its
# signature; as the build made it, it loads and does what it is for.  So
# what may load is what the kernel's build signed.
#
# NOT checked: which driver goes with which device, and a driver finding
# real hardware.  A virtual machine has none of what most of these
# drivers are for.
set -euo pipefail

fail() {
    echo "modules.sh: FAILED: $*" >&2
    exit 1
}
modules=/usr/lib/modules/$(uname -r)
if [ ! -d $modules/kernel ]; then
    [ "$(uname -m)" != x86_64 ] || fail "no modules in $modules: the image has none, or they are another kernel's"
    echo "this architecture's kernel has no modules: nothing to check"
    exit 0
fi

work=$(mktemp -d)
leave_as_found() {
    ip link del check-wg 2> /dev/null || true
    modprobe -r wireguard 2> /dev/null || true
    rm -r $work
}
trap leave_as_found EXIT

echo "udev loaded a driver for a device of this machine"
loaded_by_the_boot=$(lsmod | awk 'NR > 1 { print $1 }')
[ -n "$loaded_by_the_boot" ] || fail "udev loaded no driver from $modules for any device of this machine"
echo "  $(echo "$loaded_by_the_boot" | tr '\n' ' ')"

echo "the device of a module that is not loaded yet is there"
# made at boot from the modules' own list of such devices; opening it
# loads the module
[ -c /dev/net/tun ] || fail "no /dev/net/tun"

module=$(modinfo -n wireguard) || fail "this kernel has no wireguard module"
zstd -q -d $module -o $work/wireguard.ko
# The kernel has one answer for a signature that is wrong and for none.
# It checks the signature before it reads the module, so no other
# refusal comes first.
signature_refusal="Key was rejected"

echo "a module with a byte changed is refused"
cp $work/wireguard.ko $work/changed.ko
# sixteen bytes of the module's own code, well before the signature at
# its end
printf 'not as it was...' | dd of=$work/changed.ko bs=1 seek=4096 conv=notrunc status=none
! cmp -s $work/wireguard.ko $work/changed.ko || fail "the module was not changed"
! insmod $work/changed.ko 2> $work/changed.log || fail "a changed module was loaded"
grep -q "$signature_refusal" $work/changed.log || fail "refused, but not for its signature: $(cat $work/changed.log)"

echo "a module without its signature is refused"
# A signature is what follows the module in its file, and ends with a
# line that says it is one: without that line the kernel finds none.
marker='~Module signature appended~'
marker_length=$((${#marker} + 1))
[ "$(tail -c $marker_length $work/wireguard.ko)" = "$marker" ] || fail "the module in /usr is not signed"
head -c -$marker_length $work/wireguard.ko > $work/unsigned.ko
! insmod $work/unsigned.ko 2> $work/unsigned.log || fail "an unsigned module was loaded"
grep -q "$signature_refusal" $work/unsigned.log || fail "refused, but not for its signature: $(cat $work/unsigned.log)"

echo "as the build made it, it loads, and works"
modprobe wireguard || fail "wireguard did not load"
ip link add check-wg type wireguard || fail "no WireGuard device could be made"

echo "modules.sh: passed"

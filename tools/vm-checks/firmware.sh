# The firmware of a PC's devices on a running bunix: run on it, as root, by
#
#   BUNIX_ARCHITECTURE=x86_64 BUNIX_CHECK_SCRIPT=tools/vm-checks/firmware.sh tools/boot-vm.sh disk check
#
# For x86_64, whose system has what its kernel's modules load into their
# devices (nix/boot.nix: firmware).  An arm64 system has none of it, and
# passes with nothing checked.
#
# Each of a few drivers, of the kinds of device a PC has, finds in /usr a
# file it names as its firmware, and the file is whole.
#
# NOT checked: a device started with its firmware (a virtual machine has
# none of these devices); that every file a device may ask for is there
# (one a driver is enough here); and the processor's microcode, which is
# in the kernel image, whose build looks for it (nix/images/uki.sh).
set -euo pipefail

fail() {
    echo "firmware.sh: FAILED: $*" >&2
    exit 1
}
firmware=/usr/lib/firmware
if [ "$(uname -m)" != x86_64 ]; then
    echo "this architecture's system has no firmware: nothing to check"
    exit 0
fi

# its wired network, its Wi-Fi, its GPU
test_pc_drivers="r8169 ath10k_pci i915"
# rtw89_8852b and btrtl, not rtw89_8852be and btusb: Realtek's files are
# named by the module the others use, not the one a device is matched to
other_makers_drivers="amdgpu iwlwifi rtw89_8852b mt7921e brcmfmac btrtl tg3 bnx2"
for driver in $test_pc_drivers $other_makers_drivers; do
    echo "$driver has firmware it asks for"
    names=$(modinfo -F firmware $driver) || fail "this kernel has no $driver module"
    [ -n "$names" ] || fail "$driver names no firmware: the check asks the wrong module"
    # A driver names every file any of its devices may ask for, and the
    # system keeps only some (nix/boot/firmware.sh: keep): one found is
    # enough.
    found=
    for name in $names; do
        if [ -f $firmware/$name.zst ]; then
            found=$firmware/$name.zst
            break
        fi
    done
    [ -n "$found" ] || fail "none of the files $driver names is in $firmware (nix/boot/firmware.sh: keep)"
    # read through the name, which is often a link: zstd passes one by
    zstd -q -t < $found || fail "$found is not whole"
done

echo "firmware.sh: passed"

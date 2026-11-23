# The archive of microcode that a kernel image carries (boot.nix).
unpack $src intel
unpack $linux_firmware linux-firmware

# Intel's intel-ucode-with-caveats/ is left out: its files need a kernel
# option to load and are known to cause trouble on some machines.  So are
# the data-centre-only Xeons -- Ice Lake-SP (06-6a, 06-6c), Emerald Rapids
# (06-cf), Granite Rapids (06-ad, 06-ae), Sierra Forest (06-af) -- 7.5 MB
# of 17: the firmware reads the whole kernel image before Linux starts, at
# about 10 MB/s on a test machine.  (Sapphire Rapids, 06-8f, stays: Xeon W
# workstations.)
cd intel/intel-ucode
rm -f 06-6a-* 06-6c-* 06-cf-* 06-ad-* 06-ae-* 06-af-*
cat * > /build/GenuineIntel.bin
cd /build
cat linux-firmware/amd-ucode/microcode_amd*.bin > AuthenticAMD.bin
ls -l GenuineIntel.bin AuthenticAMD.bin

# The archive is not compressed, and has each file where the kernel
# looks for its maker's.  -t: every file's time, the same in every build.
cat > list <<END
dir kernel 0755 0 0
dir kernel/x86 0755 0 0
dir kernel/x86/microcode 0755 0 0
file kernel/x86/microcode/GenuineIntel.bin /build/GenuineIntel.bin 0644 0 0
file kernel/x86/microcode/AuthenticAMD.bin /build/AuthenticAMD.bin 0644 0 0
END
# Not at the top of the result, as the element had it: a system package
# is a tree of /usr.
mkdir -p $out/usr/lib/microcode
gen_init_cpio -t $SOURCE_DATE_EPOCH list > $out/usr/lib/microcode/microcode.cpio

# both makers ask that their terms go where their files go
install -D -m 644 intel/license $out/usr/share/licenses/microcode/LICENSE.intel-ucode
install -D -m 644 linux-firmware/LICENSES/LICENSE.amd-ucode $out/usr/share/licenses/microcode/LICENSE.amd-ucode

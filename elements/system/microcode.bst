kind: manual
description: |
  CPU microcode for Intel (Intel's releases) and AMD (linux-firmware's
  amd-ucode), as the kernel loads it at its very start: an uncompressed
  cpio archive holding kernel/x86/microcode/GenuineIntel.bin and
  AuthenticAMD.bin.  The UKIs carry it (ukify --microcode, system/uki.bst
  and system/iso.bst); systemd-stub hands it to the kernel before the
  initrd.  The firmware's own microcode is often years old, and the
  kernel's mitigations for several CPU flaws (MDS, SRBDS, GDS, MMIO stale
  data) depend on current microcode.

build-depends:
- bootstrap/build-env.bst
- base/cpio.bst

sources:
- kind: tar
  url: github:intel/Intel-Linux-Processor-Microcode-Data-Files/archive/refs/tags/microcode-20260925.tar.gz
  ref: 0ec19023dad1e6dd0c5909174b8dff2555b91cf01671e36271a1ef36655c0cfc
  directory: intel
- kind: tar
  url: kernel:linux/kernel/firmware/linux-firmware-20261019.tar.xz
  ref: a10d1ab5baf2c74ba92e8c7cf313e691696c26bddfa6df00db795e48d70cd4ca
  directory: linux-firmware

config:
  build-commands:
  # Intel's intel-ucode-with-caveats/ is left out: its files need a kernel
  # option to load and are known to cause trouble on some machines.  So are
  # the data-centre-only Xeons -- Ice Lake-SP (06-6a, 06-6c), Emerald Rapids
  # (06-cf), Granite Rapids (06-ad, 06-ae), Sierra Forest (06-af) -- 7.5 MB
  # of 17: the firmware reads the whole UKI before Linux starts, at about
  # 10 MB/s on a test machine.  (Sapphire Rapids, 06-8f, stays: Xeon W
  # workstations.)
  - |
    mkdir -p early/kernel/x86/microcode
    cd intel/intel-ucode
    rm -f 06-6a-* 06-6c-* 06-cf-* 06-ad-* 06-ae-* 06-af-*
    cat * > ../../early/kernel/x86/microcode/GenuineIntel.bin
    cd ../..
    cat linux-firmware/amd-ucode/microcode_amd*.bin > early/kernel/x86/microcode/AuthenticAMD.bin
    ls -l early/kernel/x86/microcode
    cd early
    find . | sort | cpio -o -H newc --owner=0:0 --quiet > ../microcode.cpio

  install-commands:
  - install -D -m 0644 microcode.cpio %{install-root}/microcode.cpio
  - |
    install -d %{install-root}/usr/share/licenses/microcode
    install -m 0644 intel/license %{install-root}/usr/share/licenses/microcode/intel-license
    install -m 0644 linux-firmware/LICENSES/LICENSE.amd-ucode %{install-root}/usr/share/licenses/microcode/amd-license

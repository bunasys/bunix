# What makes a bunix system boot, after elements/system/: the kernel;
# for Apple Silicon Macs their boot loader (aura), U-Boot, and the one
# file of both that a Mac's ESP has; and for PCs the firmware of their
# devices and their processors' microcode.
#
#   nix-build /bunix/nix/boot.nix -A linux
#
# Built with the system's tools, without the compiler flags the other
# groups give every package: each of these chooses its own.  The kernel
# and aura are built with clang (base.nix: llvm), U-Boot with gcc; the
# firmware and the microcode are files as their makers publish them.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  fetch = import ./fetch.nix;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
  };

  # Aurora Silicon's kernel (aurorasilicon.org): Linux with the drivers of
  # Apple Silicon Macs that are not in Linux yet, and their device trees.
  # The one kernel of bunix: it boots a virtual machine as well, and on
  # x86_64 it is the same source with that architecture's default
  # configuration (boot/linux/x86_64.config).
  linux = mkSystemPackage {
    name = "linux";
    source = sources.linux;
    script = ./boot/linux.sh;
    # glibc: for gen_init_cpio, the one program in it
    depends = [ toolchain.glibc ];
    # llvm: the kernel is built with clang.
    # rust and bindgen: parts of this kernel are written in Rust (a Mac's
    # drivers; x86 builds none of them).
    # flex, bc and perl: the kernel's own configuration and build tools.
    # openssl: the configuration has the kernel keep a keyring of
    # certificates, and what puts them into the image is built with
    # OpenSSL.
    buildDepends = [ base.llvm base.rust base.bindgen base.flex base.bc base.perl base.openssl ]
      # x86: what checks the kernel's object code reads it with libelf,
      # found through pkgconf; the kernel image is compressed with zstd
      # (CONFIG_KERNEL_ZSTD), and so are its modules; kmod's depmod
      # lists them for what loads them.
      ++ (if system == "x86_64-linux" then [ base.elfutils base.pkgconf base.zstd base.kmod ] else []);
    env = {
      options_directory = ./boot/linux;
      # whose signature on an image's hash the kernel takes: public
      verity_certificate = ../keys/verity.crt;
    };
  };

  # Aura, Aurora Silicon's boot loader for Apple Silicon Macs (from m1n1):
  # what the Mac's own firmware starts, and what starts the kernel with
  # the device tree of the machine.  At a version Aurora's own systems
  # have pinned; they are one ahead now (docs/nix-usr-system.md).  It runs on the bare machine and needs nothing of the system.
  aura = mkSystemPackage {
    name = "aura";
    source = sources.aura;
    script = ./boot/aura.sh;
    # llvm: built with clang and LLVM's linker.  rust: part of it is Rust,
    # compiled for a machine with no operating system.  python-zlib: its
    # build's own tools are Python, and one of them compresses.
    buildDepends = [ base.llvm base.rust base.rust-std-aarch64-none base.python-zlib ];
    env = {
      # The crates its Rust part is made of, each pinned; cargo downloads
      # nothing in a build.  The list is rust/Cargo.lock of the source.
      crates = map (crate: fetch {
        url = "https://static.crates.io/crates/${crate.name}/${crate.name}-${crate.version}.crate";
        inherit (crate) sha256;
      }) (builtins.fromJSON (builtins.readFile ./boot/aura-crates.json));
      # the one crate that Cargo.lock takes from a repository
      fatfs = fetch sources.aura-fatfs;
      # Each commit is the last part of its source's address: aura labels
      # itself with its own, and cargo is told the crate's.
      aura_commit = baseNameOf sources.aura.url;
      fatfs_commit = baseNameOf sources.aura-fatfs.url;
    };
  };

  # U-Boot, Aurora Silicon's (from Asahi Linux's): on a Mac it is the EFI
  # firmware the machine does not have.  aura starts it, and it starts
  # systemd-boot from the ESP as the firmware of any other machine does
  # (docs/nix-usr-system.md).  At the version Aurora's own systems pin.
  u-boot = { machine, configuration }: mkSystemPackage {
    name = "u-boot-${machine}";
    source = sources.u-boot;
    script = ./boot/u-boot.sh;
    # flex, bc: its configuration and build tools.
    # openssl: its tools for making images are built with it.
    buildDepends = [ base.flex base.bc base.openssl ];
    env = { inherit machine configuration; };
  };
  # every Apple Silicon Mac; the configuration's name is from the first
  # of them
  u-boot-apple = u-boot { machine = "apple"; configuration = "apple_m1_defconfig"; };
  # QEMU's virtual machine, for trying on it what U-Boot is to start
  u-boot-qemu = u-boot { machine = "qemu"; configuration = "qemu_arm64_defconfig"; };

  # What aura's first stage loads from a Mac's ESP: aura's second stage,
  # then the device tree of every Mac this kernel knows, then U-Boot.
  # aura picks the tree of the machine it runs on and starts U-Boot with
  # it; U-Boot hands it on to the kernel.  So the trees are this
  # kernel's, and the file is made anew with every kernel.
  mac-stage2 = mkSystemPackage {
    name = "mac-stage2";
    version = "aura-${sources.aura.version}-linux-${sources.linux.version}-u-boot-${sources.u-boot.version}";
    script = ./boot/mac-stage2.sh;
    # python-zlib: aura's tool that puts the parts together is Python,
    # and compresses U-Boot.
    buildDepends = [ aura linux u-boot-apple base.python-zlib ];
    env = {
      # the tool writes down which kernel the trees are of
      kernel_commit = baseNameOf sources.linux.url;
    };
  };

  # Device firmware from linux-firmware, cut down to what the kernel's
  # modules (boot/linux/x86_64.config) load on PCs and laptops: GPUs
  # (Intel, AMD), Wi-Fi and Bluetooth (Intel, Qualcomm/Atheros, Realtek,
  # MediaTek, Broadcom), Intel's touch and sensor hub, the wired network
  # chips that need it.  zstd-compressed, in /usr/lib/firmware.  About
  # 240 MB of linux-firmware's 2 GB; most of the rest is for servers,
  # phones, routers, TV tuners and sound DSPs.  For x86: a Mac's firmware
  # is the Mac's own, and not anyone else's to hand out.
  firmware = mkSystemPackage {
    name = "firmware";
    source = sources.linux-firmware;
    script = ./boot/firmware.sh;
    # zstd: every file is compressed
    buildDepends = [ base.zstd ];
  };

  # CPU microcode for Intel (Intel's releases) and AMD (linux-firmware's
  # amd-ucode), as the kernel loads it at its very start: an archive that
  # the kernel image carries (images/uki.sh), and systemd's stub hands to
  # the kernel before the initrd.  The firmware's own microcode is often
  # years old, and the kernel's mitigations for several CPU flaws (MDS,
  # SRBDS, GDS, MMIO stale data) depend on current microcode.  For x86.
  microcode = mkSystemPackage {
    name = "microcode";
    source = sources.intel-microcode;
    script = ./boot/microcode.sh;
    # linux: its gen_init_cpio makes the archive, as it makes an
    # initramfs (images/image.sh); cpio is not a package here
    buildDepends = [ linux ];
    # AMD's microcode comes in linux-firmware; the version is Intel's
    env = { linux_firmware = fetch sources.linux-firmware; };
  };
in
{
  inherit linux aura mac-stage2 u-boot-apple u-boot-qemu firmware microcode;
}

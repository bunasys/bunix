# What makes a bunix system boot, after elements/system/: the kernel, and
# the boot loader of Apple Silicon Macs.
#
#   nix-build /bunix/nix/boot.nix -A linux
#
# Built with clang (base.nix: llvm) and the system's tools, without the
# compiler flags the other groups give every package: the kernel and the
# boot loader choose their own.
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
  # The one kernel of bunix: it boots a virtual machine as well.
  linux = mkSystemPackage {
    name = "linux";
    source = sources.linux;
    script = ./boot/linux.sh;
    # glibc: for gen_init_cpio, the one program in it
    depends = [ toolchain.glibc ];
    # llvm: the kernel is built with clang.
    # rust and bindgen: parts of this kernel are written in Rust.
    # flex, bc and perl: the kernel's own configuration and build tools.
    # openssl: asahi.config has the kernel keep a keyring of certificates,
    # and what puts them into the image is built with OpenSSL.
    buildDepends = [ base.llvm base.rust base.bindgen base.flex base.bc base.perl base.openssl ];
    env = {
      options_directory = ./boot/linux;
      # whose signature on an image's hash the kernel takes: public
      verity_certificate = ../keys/verity.crt;
    };
  };

  # Aura, Aurora Silicon's boot loader for Apple Silicon Macs (from m1n1):
  # what the Mac's own firmware starts, and what starts the kernel with
  # the device tree of the machine.  At the version Aurora's own systems
  # pin.  It runs on the bare machine and needs nothing of the system.
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
in
{
  inherit linux aura;
}

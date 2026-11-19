# What makes a bunix system boot, after elements/system/: the kernel.
#
#   nix-build /bunix/nix/boot.nix -A linux
#
# Built with clang (base.nix: llvm) and the system's tools, without the
# compiler flags the other groups give every package: the kernel chooses
# its own.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

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
    env = { options_directory = ./boot/linux; };
  };
in
{
  inherit linux;
}

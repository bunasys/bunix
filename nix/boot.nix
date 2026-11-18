# What makes a bunix system boot, after elements/system/: the kernel.
#
#   nix-build /bunix/nix/boot.nix -A linux
#
# Built with the system's compiler and tools, without the compiler flags
# the other groups give every package: the kernel chooses its own.
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

  linux = mkSystemPackage {
    name = "linux";
    source = sources.linux;
    script = ./boot/linux.sh;
    # glibc: for gen_init_cpio, the one program in it
    depends = [ toolchain.glibc ];
    # flex and bc for the kernel's own configuration and build tools; perl
    # because arm64's kernel generates some of its assembly with perl scripts
    buildDepends = [ base.flex base.bc base.perl ];
    env = { options_directory = ./boot/linux; };
  };
in
{
  inherit linux;
}

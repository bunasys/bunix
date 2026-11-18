# What makes a bunix system boot, after elements/system/: the kernel.
#
#   nix-build /bunix/nix/system.nix -A linux
#
# Built with the system's compiler and tools, without the flags the other
# groups give every package: the kernel chooses its own.
{ system ? builtins.currentSystem }:

let
  stage2 = import ./stage2.nix { inherit system; };
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    inherit (tools) buildEnvironment;
  };

  linux = mkSystemPackage {
    name = "linux";
    source = sources.linux;
    script = ./system/linux.sh;
    # glibc: for gen_init_cpio, the one program in it
    depends = [ toolchain.glibc ];
    # flex and bc for the kernel's own configuration and build tools; perl
    # because arm64's kernel generates some of its assembly with perl scripts
    buildDepends = [ base.flex base.bc base.perl ];
    env = { options = ./system/linux; };
  };
in
{
  inherit linux;
}

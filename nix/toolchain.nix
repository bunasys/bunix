# The toolchain of the system: glibc, binutils and gcc for /usr, built by
# stage 1's gcc with stage 2's tools (docs/nix-usr-system.md).
#
#   nix-build /bunix/nix/toolchain.nix -A glibc
{ system ? builtins.currentSystem }:

let
  stage1 = import ./stage1.nix { inherit system; };
  stage2 = import ./stage2.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
  };

  # the system has no compiler or tools of its own yet
  bootstrapTools = [ stage1.gcc stage1.binutils ] ++ stage2.all;

  # The kernel's headers are stage 1's: files copied from the kernel's
  # source, which glibc installs beside its own.
  glibc = mkSystemPackage {
    name = "glibc";
    source = sources.glibc;
    script = ./toolchain/glibc.sh;
    tools = bootstrapTools;
    env = { linux_headers = stage1.linuxHeaders; };
  };
in
{
  inherit glibc;
}

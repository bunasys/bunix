# The toolchain of the system: glibc, binutils and gcc for /usr, built by
# stage 1's gcc with stage 2's tools (docs/nix-usr-system.md).
#
#   nix-build /bunix/nix/toolchain.nix -A gcc
#
#   glibc ─┬─ binutils ─┐
#          └────────────┴─ gcc
{ system ? builtins.currentSystem }:

let
  stage1 = import ./stage1.nix { inherit system; };
  stage2 = import ./stage2.nix { inherit system; };
  fetch = import ./fetch.nix;
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

  # binutils and gcc are compiled by stage 1's gcc, for the glibc above
  # (toolchain/for-usr-glibc.sh).
  binutils = mkSystemPackage {
    name = "binutils";
    source = sources.binutils;
    script = ./toolchain/binutils.sh;
    depends = [ glibc ];
    tools = bootstrapTools;
    env = { for_usr_glibc = ./toolchain/for-usr-glibc.sh; };
  };

  gcc = mkSystemPackage {
    name = "gcc";
    source = sources.gcc;
    script = ./toolchain/gcc.sh;
    depends = [ glibc binutils ];
    tools = bootstrapTools;
    env = {
      for_usr_glibc = ./toolchain/for-usr-glibc.sh;
      gmp = fetch sources.gmp;
      mpfr = fetch sources.mpfr;
      mpc = fetch sources.mpc;
    };
  };
in
{
  inherit glibc binutils gcc;
}

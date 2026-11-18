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

  architecture = import ./architecture.nix system;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    # the system has no compiler or tools of its own yet
    bootstrapTools = [ stage1.gcc stage1.binutils ] ++ stage2.all;
  };

  # For binutils and gcc, which stage 1's gcc compiles for the system.
  # (glibc is not compiled for a glibc.)  Stage 1's gcc builds programs for
  # stage 1's glibc, in the store; these flags have it use the start files
  # and libraries of the one staged at /usr, and the loader by its usual
  # path.  The headers need no flag: both glibcs are the same version, and
  # their headers the same files.
  forUsrGlibc = "-B/usr/lib/${architecture.triplet} -Wl,--dynamic-linker=${architecture.loader}";

  # The kernel's headers are stage 1's: files copied from the kernel's
  # source, which glibc installs beside its own.
  glibc = mkSystemPackage {
    name = "glibc";
    source = sources.glibc;
    script = ./toolchain/glibc.sh;
    env = { linux_headers = stage1.linuxHeaders; };
  };

  binutils = mkSystemPackage {
    name = "binutils";
    source = sources.binutils;
    script = ./toolchain/binutils.sh;
    depends = [ glibc ];
    env = { for_usr_glibc = forUsrGlibc; };
  };

  gcc = mkSystemPackage {
    name = "gcc";
    source = sources.gcc;
    script = ./toolchain/gcc.sh;
    depends = [ glibc binutils ];
    env = {
      for_usr_glibc = forUsrGlibc;
      gmp = fetch sources.gmp;
      mpfr = fetch sources.mpfr;
      mpc = fetch sources.mpc;
    };
  };
in
{
  inherit glibc binutils gcc;
}

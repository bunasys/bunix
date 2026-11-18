# Stage 3: glibc, binutils and gcc once more, and for good.  They are built
# by stage 1's gcc with stage 2's tools, and depend on nothing built before
# them: not the seed, not stage 1, not stage 2.
#
#   nix-build /bunix/nix/stage3.nix -A gcc
#
#   glibc ─┬─ binutils ─┐
#          └────────────┴─ gcc (outputs: out, lib)
#
# This gcc is a normal one, unlike stage 1's: it optimises at link time,
# and has libstdc++ and libgcc as shared libraries.  Those are an output of
# their own, gcc.lib, and a program it builds depends on glibc and gcc.lib,
# not on the compiler (stage3/gcc.sh).
#
# glibc reads the system's configuration from /etc, and is where the
# system's time zone data and locales are found through the variables
# TZDIR and LOCPATH: it has neither itself.  It does not read /etc for
# which libraries to load (stage3/glibc.sh).
#
# What it cannot do yet:
# - -fsanitize: the sanitizer libraries are not built (stage3/gcc.sh);
# - put objects compiled with -flto in a library with plain `ar`: binutils
#   is built before gcc and does not know gcc's plugin.  `gcc-ar`,
#   `gcc-ranlib` and `gcc-nm` do.
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
  stage1 = import ./stage1.nix { inherit system; };
  stage2 = import ./stage2.nix { inherit system; };
  fetch = import ./fetch.nix;
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  # from here on, build scripts are run by stage 2's bash
  mkPackage = import ./package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
  };

  # What every package of this stage has in common.
  stage3Package = package: mkPackage ({
    tools = stage2.all ++ [ stage1.gcc stage1.binutils ];
    mustNotDependOn = [ seed ] ++ stage1.all ++ stage2.all;
  } // package);

  # No stage in the names: these are the final ones.
  #
  # The kernel's headers are stage 1's: they are files copied from the
  # kernel's source, the same whoever copies them, and glibc copies them
  # again into itself.
  glibc = stage3Package {
    name = "glibc";
    source = sources.glibc;
    script = ./stage3/glibc.sh;
    env = { linux_headers = stage1.linuxHeaders; };
  };

  binutils = stage3Package {
    name = "binutils";
    source = sources.binutils;
    script = ./stage3/binutils.sh;
    env = { inherit glibc; };
  };

  gcc = stage3Package {
    name = "gcc";
    source = sources.gcc;
    script = ./stage3/gcc.sh;
    outputs = [ "out" "lib" ];
    # this stage's ar and ranlib make gcc's libraries
    tools = [ binutils ] ++ stage2.all ++ [ stage1.gcc stage1.binutils ];
    env = {
      inherit glibc binutils;
      gmp = fetch sources.gmp;
      mpfr = fetch sources.mpfr;
      mpc = fetch sources.mpc;
    };
  };
in
{
  inherit glibc binutils gcc;
}

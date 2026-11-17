# Stage 1: glibc, binutils and gcc in the store, built by the seed.
#
#   nix-build /bunix/nix/stage1.nix -A gcc
#
# The seed's gcc builds programs for the seed's own glibc.  Stage 1's gcc
# builds them for stage 1's glibc: its headers, its start files and its
# loader, all by their store paths.  Everything after is built with it.
#
#   linuxHeaders ─┐
#   m4 ─ bison ───┼─ glibc ─┬─ binutils ─┐
#   python ───────┘         └────────────┴─ gcc
#
# The seed builds glibc, binutils and gcc, and that is all: its store path
# may not appear in them (mustNotReference), or everything built with them
# would depend on the seed.  The stage's own build tools (m4, bison,
# Python) are linked with the seed and are not used after it.
#
# What this gcc cannot do, because its libgcc and libstdc++ are static
# only: link a shared library written in C++, and build a dynamic program
# that calls pthread_exit or pthread_cancel (glibc loads libgcc_s.so for
# those).  Stages 2 and 3 need neither.
#
# `system` is the architecture: by default the machine's that evaluates
# this.  What differs by architecture is written where it is used, as a
# `case $system` in a build script; `grep -rn aarch64-linux nix` finds every
# place.  Two more are per architecture: the seed (seed.nix) and the path of
# /bin/sh in the builder's nix.conf (sh.nix).
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
  fetch = import ./fetch.nix;
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkPackage = import ./package.nix {
    inherit system;
    shell = "${seed}/bin/bash";
  };

  # A program the seed's gcc links asks for a loader in /lib, which is not
  # there, so by default it cannot start.  A build tool that only has to
  # run during this stage is linked one of two ways:
  #
  #   static                 no loader needed (staticCc, staticCxx)
  #   against the seed's     the seed's own loader and libraries, by
  #   glibc                  path; python.sh does this
  #
  # Static is part of the compiler's name, not of LDFLAGS: a configure
  # script may compile and run a program without LDFLAGS (gmp's does).
  staticCc = "gcc --static";
  staticCxx = "g++ --static";

  linuxHeaders = mkPackage {
    name = "stage1-linux-headers";
    source = sources.linux;
    script = ./stage1/linux-headers.sh;
    tools = [ seed ];
    env = { CC = staticCc; };
  };

  # bison needs it, to build and to run
  m4 = mkPackage {
    name = "stage1-m4";
    source = sources.m4;
    script = ./stage1/m4.sh;
    tools = [ seed ];
    env = { CC = staticCc; };
  };

  # glibc's build needs bison and Python; the seed has neither
  bison = mkPackage {
    name = "stage1-bison";
    source = sources.bison;
    script = ./stage1/bison.sh;
    tools = [ m4 seed ];
    env = { CC = staticCc; };
  };

  # not static: Python loads its own modules as shared libraries
  python = mkPackage {
    name = "stage1-python";
    source = sources.python;
    script = ./stage1/python.sh;
    tools = [ seed ];
    env = { inherit seed; };
  };

  glibc = mkPackage {
    name = "stage1-glibc";
    source = sources.glibc;
    script = ./stage1/glibc.sh;
    tools = [ bison python seed ];
    mustNotReference = [ seed ];
    env = { linux_headers = linuxHeaders; };
  };

  # binutils and gcc are static programs, as the seed's are: what matters
  # is the glibc they build for, not the one inside them.
  binutils = mkPackage {
    name = "stage1-binutils";
    source = sources.binutils;
    script = ./stage1/binutils.sh;
    tools = [ seed ];
    mustNotReference = [ seed ];
    env = {
      CC = staticCc;
      CXX = staticCxx;
      inherit glibc;
    };
  };

  gcc = mkPackage {
    name = "stage1-gcc";
    source = sources.gcc;
    script = ./stage1/gcc.sh;
    tools = [ binutils seed ];
    mustNotReference = [ seed ];
    env = {
      CC = staticCc;
      CXX = staticCxx;
      inherit glibc binutils;
      gmp = fetch sources.gmp;
      mpfr = fetch sources.mpfr;
      mpc = fetch sources.mpc;
    };
  };
in
{
  inherit linuxHeaders m4 bison python glibc binutils gcc;
}

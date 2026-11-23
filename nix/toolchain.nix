# The toolchain of the system: glibc, binutils and gcc for /usr, built by
# stage 1's gcc with stage 2's tools (docs/nix-usr-system.md).
#
#   nix-build /bunix/nix/toolchain.nix -A gcc
#
#   glibc ─┬─ binutils ─┐
#          └────────────┴─ gccWhole ─┬─ gccLibraries
#                                    └─ gcc
#
# gcc is built once (gccWhole) and shipped as two packages: the shared
# libraries that what it compiles needs to run (libstdc++.so.6,
# libgcc_s.so.1...), and the compiler.  A C++ program depends on the
# first, 11 MB, and an image with it has no compiler.
{ system ? builtins.currentSystem }:

let
  stage1 = import ./bootstrap/stage1.nix { inherit system; };
  stage2 = import ./bootstrap/stage2.nix { inherit system; };
  fetch = import ./fetch.nix;
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  architecture = import ./architecture.nix system;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
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

  # nothing depends on this one but its two parts
  gccWhole = mkSystemPackage {
    name = "gcc-whole";
    source = sources.gcc;
    script = ./toolchain/gcc-whole.sh;
    depends = [ glibc binutils ];
    env = {
      for_usr_glibc = forUsrGlibc;
      gmp = fetch sources.gmp;
      mpfr = fetch sources.mpfr;
      mpc = fetch sources.mpc;
    };
  };

  gccLibraries = mkSystemPackage {
    name = "gcc-libraries";
    version = sources.gcc.version;
    script = ./toolchain/gcc-libraries.sh;
    depends = [ glibc ];
    env = { whole = gccWhole; };
  };

  gcc = mkSystemPackage {
    name = "gcc";
    version = sources.gcc.version;
    script = ./toolchain/gcc.sh;
    depends = [ glibc binutils gccLibraries ];
    env = { whole = gccWhole; libraries = gccLibraries; };
  };

  # What clang needs of gcc to compile for this system, and its settings
  # here (toolchain/clang-setup.sh): for the llvm extension, which has
  # clang and not gcc (images/llvm.nix).  LLVM is base.nix's.
  clangSetup = mkSystemPackage {
    name = "clang-setup";
    version = sources.gcc.version;
    script = ./toolchain/clang-setup.sh;
    depends = [ glibc gccLibraries ];
    env = { whole = gccWhole; };
  };
in
{
  inherit glibc binutils gccWhole gccLibraries gcc clangSetup;
}

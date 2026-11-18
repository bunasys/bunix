# The tools a build runs, as system packages: a shell, make, tar, sed and
# the rest, in /usr/bin (docs/nix-usr-system.md).
#
#   nix-build /bunix/nix/tools.nix -A buildEnvironment
#
# Stage 2 has the same tools in the store.  A build that finds sed there
# may write that path into what it installs, and a system package may not
# name the store; found in /usr/bin, sed is where the system will have it.
# So these are built once more, by the system's gcc, and with the
# toolchain they are what every later package is built with:
# `buildEnvironment`.
#
# Stage 2's tools are still on PATH while these are built, after /usr/bin.
# Each package is built with the ones before it already in /usr: coreutils
# first, so that install and mkdir are the system's for everything after.
#
# Whether a bunix image ships these is another matter: its coreutils is
# not GNU's (elements/base/uutils-coreutils.bst).
{ system ? builtins.currentSystem }:

let
  stage2 = import ./stage2.nix { inherit system; };
  toolchain = import ./toolchain.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    bootstrapTools = stage2.all;
    # gcc's depends bring glibc, binutils and its libraries
    buildEnvironment = [ toolchain.gcc ];
    # as include/system.yml has them.  gcc already defaults to PIE and the
    # stack protector.
    defaults = {
      CFLAGS = "-O2 -pipe -fno-plt";
      CXXFLAGS = "-O2 -pipe -fno-plt";
      LDFLAGS = "-Wl,-O1,--as-needed";
    };
  };

  # Every one needs glibc to run, and is built with those before it.
  tool = package: mkSystemPackage ({
    script = ./autotools.sh;
    depends = [ toolchain.glibc ];
  } // package);

  coreutils = tool {
    name = "coreutils";
    source = sources.coreutils;
    env = {
      configure_arguments = "--disable-nls --enable-install-program=hostname --enable-no-install-program=kill,uptime";
      # a staged build is root, which coreutils' configure refuses without this
      FORCE_UNSAFE_CONFIGURE = "1";
    };
  };

  sed = tool {
    name = "sed";
    source = sources.sed;
    buildDepends = [ coreutils ];
    env = { configure_arguments = "--disable-nls"; };
  };

  grep = tool {
    name = "grep";
    source = sources.grep;
    buildDepends = [ coreutils sed ];
    env = { configure_arguments = "--disable-nls"; };
  };

  gawk = tool {
    name = "gawk";
    source = sources.gawk;
    buildDepends = [ coreutils sed grep ];
    env = { configure_arguments = "--disable-nls"; };
  };

  # the first four, which nearly every configure script runs
  first = [ coreutils sed grep gawk ];

  bash = tool {
    name = "bash";
    source = sources.bash;
    script = ./tools/bash.sh;
    buildDepends = first;
  };

  diffutils = tool {
    name = "diffutils";
    source = sources.diffutils;
    buildDepends = first;
    env = { configure_arguments = "--disable-nls"; };
  };

  findutils = tool {
    name = "findutils";
    source = sources.findutils;
    buildDepends = first;
    env = { configure_arguments = "--disable-nls"; };
  };

  make = tool {
    name = "make";
    source = sources.make;
    buildDepends = first;
    env = { configure_arguments = "--disable-nls --without-guile"; };
  };

  patch = tool {
    name = "patch";
    source = sources.patch;
    buildDepends = first;
    env = { configure_arguments = "--disable-nls"; };
  };

  tar = tool {
    name = "tar";
    source = sources.tar;
    buildDepends = first;
    env = {
      configure_arguments = "--disable-nls --without-selinux --without-posix-acls";
      # as for coreutils
      FORCE_UNSAFE_CONFIGURE = "1";
    };
  };

  gzip = tool {
    name = "gzip";
    source = sources.gzip;
    script = ./tools/gzip.sh;
    buildDepends = first;
  };

  xz = tool {
    name = "xz";
    source = sources.xz;
    buildDepends = first;
    env = { configure_arguments = "--disable-static --disable-nls --disable-doc"; };
  };

  m4 = tool {
    name = "m4";
    source = sources.m4;
    buildDepends = first;
    env = { configure_arguments = "--disable-nls"; };
  };

  # bison runs m4, and records where it is
  bison = tool {
    name = "bison";
    source = sources.bison;
    depends = [ toolchain.glibc m4 ];
    buildDepends = first;
    env = { configure_arguments = "--disable-nls"; };
  };

  # Enough of Python for a build to run scripts with (glibc's does).  The
  # one a system ships has more modules, each needing a library.
  python = tool {
    name = "python";
    source = sources.python;
    buildDepends = first;
    env = { configure_arguments = "--without-ensurepip --disable-test-modules"; };
  };

  all = first ++ [ bash diffutils findutils make patch tar gzip xz m4 bison python ];
in
{
  inherit coreutils sed grep gawk bash diffutils findutils make patch tar gzip xz m4 bison python all;

  # what a package is built with, once these exist: the compiler and the
  # tools, all in /usr, and nothing of the bootstrap on PATH
  buildEnvironment = [ toolchain.gcc ] ++ all;
}

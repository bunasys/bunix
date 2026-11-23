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
# `buildEnvironment`, as bootstrap/build-env.bst is for a .bst element.
#
# Stage 2's tools are still on PATH while these are built, after /usr/bin.
# Each package is built with the ones before it already in /usr: coreutils
# first, so that install and mkdir are the system's for everything after;
# then bash, which the scripts of the others are run by.
#
# An image ships these same packages: GNU's, and no BusyBox.
{ system ? builtins.currentSystem }:

let
  stage2 = import ./bootstrap/stage2.nix { inherit system; };
  toolchain = import ./toolchain.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (toolchain) glibc;

  # The compiler's flags for a system package, as include/system.yml has
  # them.  gcc already defaults to PIE and the stack protector.
  compilerFlags = {
    CFLAGS = "-O2 -pipe -fno-plt";
    CXXFLAGS = "-O2 -pipe -fno-plt";
    LDFLAGS = "-Wl,-O1,--as-needed";
  };

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    bootstrapTools = stage2.all;
    # the compiler; its depends bring glibc, binutils and its libraries
    buildEnvironment = [ toolchain.gcc ];
    defaultEnv = compilerFlags;
  };

  coreutils = mkSystemPackage {
    name = "coreutils";
    source = sources.coreutils;
    script = ./autotools.sh;
    depends = [ glibc ];
    env = {
      configure_arguments = "--disable-nls --enable-install-program=hostname --enable-no-install-program=kill,uptime";
      # a staged build is root, which coreutils' configure refuses without this
      FORCE_UNSAFE_CONFIGURE = "1";
    };
  };

  # The terminal library: what bash's line editor asks how to clear a line
  # or move the cursor on the terminal in use.
  ncurses = mkSystemPackage {
    name = "ncurses";
    source = sources.ncurses;
    script = ./tools/ncurses.sh;
    depends = [ glibc ];
    buildDepends = [ coreutils ];
  };

  bash = mkSystemPackage {
    name = "bash";
    source = sources.bash;
    script = ./tools/bash.sh;
    depends = [ glibc ncurses ];
    buildDepends = [ coreutils ];
  };

  sed = mkSystemPackage {
    name = "sed";
    source = sources.sed;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = [ coreutils bash ];
    env = { configure_arguments = "--disable-nls"; };
  };

  # Without Perl's regular expressions (grep -P), which elements/base/grep.bst
  # has: that needs pcre2.  bash: egrep and fgrep are scripts.
  grep = mkSystemPackage {
    name = "grep";
    source = sources.grep;
    script = ./autotools.sh;
    depends = [ glibc bash ];
    buildDepends = [ coreutils sed ];
    env = { configure_arguments = "--disable-nls"; };
  };

  # bash: gawkbug is a script
  gawk = mkSystemPackage {
    name = "gawk";
    source = sources.gawk;
    script = ./autotools.sh;
    depends = [ glibc bash ];
    buildDepends = [ coreutils sed grep ];
    env = { configure_arguments = "--disable-nls"; };
  };

  # what nearly every configure script runs
  configureTools = [ coreutils bash sed grep gawk ];

  diffutils = mkSystemPackage {
    name = "diffutils";
    source = sources.diffutils;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls"; };
  };

  # bash: updatedb is a script
  findutils = mkSystemPackage {
    name = "findutils";
    source = sources.findutils;
    script = ./autotools.sh;
    depends = [ glibc bash ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls"; };
  };

  make = mkSystemPackage {
    name = "make";
    source = sources.make;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls --without-guile"; };
  };

  patch = mkSystemPackage {
    name = "patch";
    source = sources.patch;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls"; };
  };

  tar = mkSystemPackage {
    name = "tar";
    source = sources.tar;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = configureTools;
    env = {
      configure_arguments = "--disable-nls --without-selinux --without-posix-acls";
      # as for coreutils
      FORCE_UNSAFE_CONFIGURE = "1";
    };
  };

  # bash: zcat, zgrep and ten more are scripts
  gzip = mkSystemPackage {
    name = "gzip";
    source = sources.gzip;
    script = ./tools/gzip.sh;
    depends = [ glibc bash ];
    buildDepends = configureTools;
  };

  # Also liblzma, which other packages read and write .xz with.  bash:
  # xzgrep, xzdiff and two more are scripts.
  xz = mkSystemPackage {
    name = "xz";
    source = sources.xz;
    script = ./autotools.sh;
    depends = [ glibc bash ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-static --disable-nls --disable-doc"; };
  };

  m4 = mkSystemPackage {
    name = "m4";
    source = sources.m4;
    script = ./autotools.sh;
    depends = [ glibc ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls"; };
  };

  # bison runs m4, and records where it is.  bash: yacc is a script.
  bison = mkSystemPackage {
    name = "bison";
    source = sources.bison;
    script = ./autotools.sh;
    depends = [ glibc m4 bash ];
    buildDepends = configureTools;
    env = { configure_arguments = "--disable-nls"; };
  };

  # Enough of Python for a build to run scripts with (glibc's does).  The
  # one a system ships has more modules, each needing a library.
  # bash: python3-config is a script.
  python = mkSystemPackage {
    name = "python";
    source = sources.python;
    script = ./autotools.sh;
    depends = [ glibc bash ];
    buildDepends = configureTools;
    env = { configure_arguments = "--without-ensurepip --disable-test-modules"; };
  };

  all = configureTools ++ [ ncurses diffutils findutils make patch tar gzip xz m4 bison python ];
in
{
  inherit coreutils ncurses bash sed grep gawk diffutils findutils make patch tar gzip xz m4 bison python all;
  inherit compilerFlags;

  # what a package is built with, once these exist: the compiler and the
  # tools, all in /usr, and nothing of the bootstrap on PATH
  buildEnvironment = [ toolchain.gcc ] ++ all;
}

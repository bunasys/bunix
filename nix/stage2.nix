# Stage 2: the tools a build runs (a shell, make, tar, sed and the rest),
# built by stage 1's gcc for stage 1's glibc.
#
#   nix-build /bunix/nix/stage2.nix -A all
#
# Stage 1 was built with the seed's tools; stage 2 is built with them too,
# for the last time.  From stage 3 on, a build's PATH is stage 2's tools
# and stage 1's compiler.  The seed's bash still runs as /bin/sh, for make
# recipes and scripts that start with #!/bin/sh (sh.nix).
#
# No package of this stage may depend on the seed (mustNotDependOn): stage
# 3 will depend on these, and would then depend on the seed through them.
# A configure script finds programs such as install or grep on PATH, where
# they are still the seed's, and some packages write the path it found into
# what they install.  Those are told the program's plain name instead: in
# configure_arguments, or in the package's own script when it has one.
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
  stage1 = import ./stage1.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkPackage = import ./package.nix {
    inherit system;
    shell = "${seed}/bin/bash";
  };

  # What every package of this stage has in common.  The tools are stage
  # 1's compiler and linker first, then the seed for everything else.
  stage2Package = package: mkPackage ({
    tools = [ stage1.gcc stage1.binutils seed ];
    mustNotDependOn = [ seed ];
  } // package);

  bash = stage2Package {
    name = "stage2-bash";
    source = sources.bash;
    script = ./stage2/bash.sh;
  };

  coreutils = stage2Package {
    name = "stage2-coreutils";
    source = sources.coreutils;
    script = ./configure-make-install.sh;
    env = { configure_arguments = "--enable-install-program=hostname --enable-no-install-program=kill,uptime"; };
  };

  diffutils = stage2Package {
    name = "stage2-diffutils";
    source = sources.diffutils;
    script = ./configure-make-install.sh;
    # pr by its name, not the seed's path (see the top): `diff -l` runs it
    env = { configure_arguments = "ac_cv_path_PR_PROGRAM=pr"; };
  };

  findutils = stage2Package {
    name = "stage2-findutils";
    source = sources.findutils;
    script = ./configure-make-install.sh;
    # sort by its name, not the seed's path (see the top): updatedb runs it
    env = { configure_arguments = "ac_cv_path_SORT=sort"; };
  };

  gawk = stage2Package {
    name = "stage2-gawk";
    source = sources.gawk;
    script = ./configure-make-install.sh;
  };

  grep = stage2Package {
    name = "stage2-grep";
    source = sources.grep;
    script = ./configure-make-install.sh;
  };

  gzip = stage2Package {
    name = "stage2-gzip";
    source = sources.gzip;
    script = ./stage2/gzip.sh;
  };

  make = stage2Package {
    name = "stage2-make";
    source = sources.make;
    script = ./configure-make-install.sh;
    env = { configure_arguments = "--without-guile"; };
  };

  patch = stage2Package {
    name = "stage2-patch";
    source = sources.patch;
    script = ./configure-make-install.sh;
  };

  sed = stage2Package {
    name = "stage2-sed";
    source = sources.sed;
    script = ./configure-make-install.sh;
  };

  tar = stage2Package {
    name = "stage2-tar";
    source = sources.tar;
    script = ./configure-make-install.sh;
  };

  xz = stage2Package {
    name = "stage2-xz";
    source = sources.xz;
    script = ./configure-make-install.sh;
  };

  # The three that glibc's build needs besides the usual tools.  Stage 1
  # has them too, but linked with the seed's glibc.
  m4 = stage2Package {
    name = "stage2-m4";
    source = sources.m4;
    script = ./configure-make-install.sh;
  };

  bison = stage2Package {
    name = "stage2-bison";
    source = sources.bison;
    script = ./configure-make-install.sh;
    # bison runs m4, and records where it is
    tools = [ m4 stage1.gcc stage1.binutils seed ];
  };

  python = stage2Package {
    name = "stage2-python";
    source = sources.python;
    script = ./stage2/python.sh;
  };
in
{
  inherit bash coreutils diffutils findutils gawk grep gzip make patch sed tar xz m4 bison python;

  # every tool of the stage: what stage 3 has on its PATH
  all = [ bash coreutils diffutils findutils gawk grep gzip make patch sed tar xz m4 bison python ];
}

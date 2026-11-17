# Stage 2: the tools a build runs (a shell, make, tar, sed and the rest),
# built by stage 1's gcc for stage 1's glibc.
#
#   nix-build /bunix/nix/stage2.nix -A all
#
# Stage 1 was built with the seed's tools; stage 2 is built with them too,
# for the last time.  From stage 3 on, a build's PATH is stage 2's tools
# and stage 1's compiler: no program of the seed's runs.
#
# Most of these are built the same way, by stage2/configure-make-install.sh;
# what a package adds to `./configure` is its configure_flags.
#
# None may name the seed's store path (mustNotReference): stage 3 will
# depend on these, and would then depend on the seed through them.  A
# configure script finds programs such as install or grep on PATH, where
# they are still the seed's, and some packages write the path it found into
# what they install.  Those are told the program's plain name instead.
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
  stage1 = import ./stage1.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  mkPackage = import ./package.nix {
    inherit system;
    shell = "${seed}/bin/bash";
  };

  # stage 1's compiler and linker first, then the seed for everything else
  buildTools = [ stage1.gcc stage1.binutils seed ];
  configureMakeInstall = ./stage2/configure-make-install.sh;

  bash = mkPackage {
    name = "stage2-bash";
    source = sources.bash;
    script = ./stage2/bash.sh;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  coreutils = mkPackage {
    name = "stage2-coreutils";
    source = sources.coreutils;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
    env = { configure_flags = "--enable-install-program=hostname --enable-no-install-program=kill,uptime"; };
  };

  diffutils = mkPackage {
    name = "stage2-diffutils";
    source = sources.diffutils;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
    # diff runs pr for `diff -l`
    env = { configure_flags = "ac_cv_path_PR_PROGRAM=pr"; };
  };

  findutils = mkPackage {
    name = "stage2-findutils";
    source = sources.findutils;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
    # the updatedb script runs sort
    env = { configure_flags = "ac_cv_path_SORT=sort"; };
  };

  gawk = mkPackage {
    name = "stage2-gawk";
    source = sources.gawk;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  grep = mkPackage {
    name = "stage2-grep";
    source = sources.grep;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  gzip = mkPackage {
    name = "stage2-gzip";
    source = sources.gzip;
    script = ./stage2/gzip.sh;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  make = mkPackage {
    name = "stage2-make";
    source = sources.make;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
    env = { configure_flags = "--without-guile"; };
  };

  patch = mkPackage {
    name = "stage2-patch";
    source = sources.patch;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  sed = mkPackage {
    name = "stage2-sed";
    source = sources.sed;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  tar = mkPackage {
    name = "stage2-tar";
    source = sources.tar;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  xz = mkPackage {
    name = "stage2-xz";
    source = sources.xz;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  # The three that glibc's build needs besides the usual tools.  Stage 1
  # has them too, but linked with the seed's glibc.
  m4 = mkPackage {
    name = "stage2-m4";
    source = sources.m4;
    script = configureMakeInstall;
    tools = buildTools;
    mustNotReference = [ seed ];
  };

  bison = mkPackage {
    name = "stage2-bison";
    source = sources.bison;
    script = configureMakeInstall;
    tools = [ m4 ] ++ buildTools;
    mustNotReference = [ seed ];
  };

  python = mkPackage {
    name = "stage2-python";
    source = sources.python;
    script = ./stage2/python.sh;
    tools = buildTools;
    mustNotReference = [ seed ];
  };
in
{
  inherit bash coreutils diffutils findutils gawk grep gzip make patch sed tar xz m4 bison python;

  # every tool of the stage: what stage 3 has on its PATH
  all = [ bash coreutils diffutils findutils gawk grep gzip make patch sed tar xz m4 bison python ];
}

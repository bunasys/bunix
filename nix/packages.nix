# The packages: what a bunix system is made of.  Each is built by stage 3's
# gcc for stage 3's glibc, with stage 2's tools, and may not depend on
# anything of the bootstrap before stage 3.
#
#   nix-build /bunix/nix/packages.nix -A file
#
# A package that uses another's library lists it in `libraries`
# (package.nix).  One built with -flto sets AR, RANLIB and NM to gcc-ar,
# gcc-ranlib and gcc-nm in its env: the plain ones cannot read its objects
# (stage3.nix).  A package with a build script of its own keeps it in
# packages/<name>.sh.
{ system ? builtins.currentSystem }:

let
  seed = import ./seed.nix { inherit system; };
  stage1 = import ./stage1.nix { inherit system; };
  stage2 = import ./stage2.nix { inherit system; };
  stage3 = import ./stage3.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);

  mkPackage = import ./package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
  };

  # the tools a build has unless it says otherwise
  buildTools = [ stage3.gcc stage3.binutils ] ++ stage2.all;

  # What every package has in common.
  systemPackage = package: mkPackage ({
    tools = buildTools;
    mustNotDependOn = [ seed ] ++ stage1.all ++ stage2.all;
  } // package);

  # ---- Libraries -----------------------------------------------------------

  zlib = systemPackage {
    name = "zlib";
    source = sources.zlib;
    script = ./configure-make-install.sh;
  };

  # `file` names the kind of a file by its content; libtool's configure
  # scripts run it.  With zlib it also looks inside compressed files.
  file = systemPackage {
    name = "file";
    source = sources.file;
    script = ./configure-make-install.sh;
    libraries = [ zlib ];
  };

  # ---- The shell and the usual commands -----------------------------------

  bash = systemPackage {
    name = "bash";
    source = sources.bash;
    script = ./packages/bash.sh;
  };

  coreutils = systemPackage {
    name = "coreutils";
    source = sources.coreutils;
    script = ./configure-make-install.sh;
    env = { configure_arguments = "--enable-install-program=hostname --enable-no-install-program=kill,uptime"; };
  };

  # mount, and the rest of what talks to the kernel about disks, terminals
  # and processes
  util-linux = systemPackage {
    name = "util-linux";
    source = sources.util-linux;
    script = ./stage2/util-linux.sh;
  };

  # ---- Build tools ---------------------------------------------------------

  m4 = systemPackage {
    name = "m4";
    source = sources.m4;
    script = ./configure-make-install.sh;
  };

  # flex runs m4, and records where it is: ours, so before stage 2's on PATH
  flex = systemPackage {
    name = "flex";
    source = sources.flex;
    script = ./configure-make-install.sh;
    tools = [ m4 ] ++ buildTools;
    # _GNU_SOURCE: without it flex 2.6.4 calls reallocarray undeclared, and
    # crashes while it builds itself
    env = { configure_arguments = "--disable-nls CPPFLAGS=-D_GNU_SOURCE"; };
  };

  bc = systemPackage {
    name = "bc";
    source = sources.bc;
    script = ./packages/bc.sh;
  };

  perl = systemPackage {
    name = "perl";
    source = sources.perl;
    script = ./packages/perl.sh;
    env = { glibc = stage3.glibc; };
  };

  # ---- The kernel ----------------------------------------------------------

  linux = systemPackage {
    name = "linux";
    source = sources.linux;
    script = ./packages/linux.sh;
    # flex and bc for the kernel's own configuration and build tools; perl
    # because arm64's kernel generates some of its assembly with perl scripts
    tools = [ flex bc perl ] ++ buildTools;
    env = { options = ./packages/linux; };
  };
in
{
  inherit zlib file bash coreutils util-linux m4 flex bc perl linux;
}

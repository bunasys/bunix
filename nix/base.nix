# Packages of a bunix system, after elements/base/: each is built with the
# system's own compiler and tools (tools.nix), and nothing of the bootstrap.
#
#   nix-build /bunix/nix/base.nix -A util-linux
#
# A package says what it needs to run (depends) and what else its build
# needs (buildDepends).  One that is configured, built and installed the
# usual way uses autotools.sh; another has its script in base/.
{ system ? builtins.currentSystem }:

let
  stage2 = import ./stage2.nix { inherit system; };
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (toolchain) glibc;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    inherit (tools) buildEnvironment;
    defaults = tools.flags;
  };

  # ---- Libraries -----------------------------------------------------------

  ncurses = mkSystemPackage {
    name = "ncurses";
    source = sources.ncurses;
    script = ./base/ncurses.sh;
    depends = [ glibc ];
  };

  readline = mkSystemPackage {
    name = "readline";
    source = sources.readline;
    script = ./base/readline.sh;
    depends = [ glibc ncurses ];
    # upstream's fixes since 8.3, as they publish them
    env = {
      patches = [
        ../files/readline/readline83-001
        ../files/readline/readline83-002
        ../files/readline/readline83-003
        ../files/readline/readline83-004
        ../files/readline/readline83-005
        ../files/readline/readline83-006
      ];
    };
  };

  # ---- Commands --------------------------------------------------------------

  # mount, and the rest of what talks to the kernel about disks, terminals
  # and processes
  util-linux = mkSystemPackage {
    name = "util-linux";
    source = sources.util-linux;
    script = ./base/util-linux.sh;
    depends = [ glibc ncurses readline ];
    buildDepends = [ pkgconf ];
  };

  # ---- Build tools -----------------------------------------------------------

  pkgconf = mkSystemPackage {
    name = "pkgconf";
    source = sources.pkgconf;
    script = ./base/pkgconf.sh;
    depends = [ glibc ];
  };

  # flex runs m4
  flex = mkSystemPackage {
    name = "flex";
    source = sources.flex;
    script = ./autotools.sh;
    depends = [ glibc tools.m4 ];
    env = { configure_arguments = "--disable-static --disable-nls"; };
  };

  bc = mkSystemPackage {
    name = "bc";
    source = sources.bc;
    script = ./base/bc.sh;
    depends = [ glibc ];
  };

  perl = mkSystemPackage {
    name = "perl";
    source = sources.perl;
    script = ./base/perl.sh;
    depends = [ glibc ];
  };
in
{
  inherit ncurses readline util-linux pkgconf flex bc perl;
}

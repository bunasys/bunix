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

  # What every package has in common.
  systemPackage = package: mkPackage ({
    tools = [ stage3.gcc stage3.binutils ] ++ stage2.all;
    mustNotDependOn = [ seed ] ++ stage1.all ++ stage2.all;
  } // package);

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
in
{
  inherit zlib file;
}

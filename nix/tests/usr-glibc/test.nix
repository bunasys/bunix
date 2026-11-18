# A build is given a /usr made of its dependencies, and a program built for
# /usr runs there: stage 1's gcc, pointed at the staged glibc, builds one
# that asks for the loader by its usual path and names no store path.
#
#   nix-build /bunix/nix/tests/usr-glibc/test.nix
{ system ? builtins.currentSystem }:

let
  stage1 = import ../../stage1.nix { inherit system; };
  stage2 = import ../../stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  binDirectories = packages:
    builtins.concatStringsSep ":" (map (package: "${package}/bin") packages);
in
derivation {
  name = "usr-glibc";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ../../stage.sh ];
  PATH = binDirectories (stage2.all ++ [ stage2.util-linux ]);
  toolsPath = binDirectories ([ stage1.gcc stage1.binutils ] ++ stage2.all);
  inside = ./build.sh;
  exportReferencesGraph = [ "closure-glibc" toolchain.glibc ];
  hello_c = ../hello.c;
}

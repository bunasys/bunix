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
  stagedBuild = import ../../stage.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
  };
in
stagedBuild {
  name = "usr-glibc";
  run = ./build.sh;
  buildDepends = [ toolchain.glibc ];
  bootstrapTools = [ stage1.gcc stage1.binutils ] ++ stage2.all;
  env = { hello_c = ../hello.c; };
}

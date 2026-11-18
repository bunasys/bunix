# Staging itself: a build with many dependencies sees every one of them in
# /usr, and can write to none of them.
#
#   nix-build /bunix/nix/tests/usr-staging/test.nix
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../stage2.nix { inherit system; };
  stagedBuild = import ../../stage.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
  };

  # a package with one file, /usr/share/layers/<number>
  layer = number: stagedBuild {
    name = "layer-${toString number}";
    run = ./layer.sh;
    bootstrapTools = stage2.all;
    env = { inherit number; };
  };
  layers = map layer [
     1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
    21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40
    41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60
  ];
in
stagedBuild {
  name = "usr-staging";
  run = ./build.sh;
  buildDepends = layers;
  bootstrapTools = stage2.all;
  env = { one_layer = builtins.head layers; };
}

# Stage 2's tools are enough to build with: a small package is unpacked,
# patched and built by make, with stage 2's tools and stage 1's compiler on
# PATH and nothing of the seed's.  (/bin/sh is still the seed's bash.)
#
#   nix-build /bunix/nix/tests/stage2-hello/test.nix
{ system ? builtins.currentSystem }:

let
  seed = import ../../bootstrap/seed.nix { inherit system; };
  stage1 = import ../../bootstrap/stage1.nix { inherit system; };
  stage2 = import ../../bootstrap/stage2.nix { inherit system; };
  tools = stage2.all ++ [ stage1.gcc stage1.binutils ];
in
derivation {
  name = "stage2-hello";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ./build.sh ];
  PATH = builtins.concatStringsSep ":" (map (tool: "${tool}/bin") tools);
  inherit seed;
  hello_c = ../hello.c;
}

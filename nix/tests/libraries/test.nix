# A package finds another's library when it is built and when it runs:
# `file` is built with `libraries = [ zlib ]` (packages.nix), and nothing
# else says where zlib is.
#
#   nix-build /bunix/nix/tests/libraries/test.nix
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../stage2.nix { inherit system; };
  stage3 = import ../../stage3.nix { inherit system; };
  packages = import ../../packages.nix { inherit system; };
  tools = [ packages.file stage3.binutils ] ++ stage2.all;
in
derivation {
  name = "libraries";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ./build.sh ];
  PATH = builtins.concatStringsSep ":" (map (tool: "${tool}/bin") tools);
  file = packages.file;
  zlib = packages.zlib;
}

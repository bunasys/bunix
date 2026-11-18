# The builder VM's sandbox holds: a build sees no file system but the
# store, /bin/sh and its own scratch directories, is not root, and has no
# network.
#
#   nix-build /bunix/nix/tests/sandbox/test.nix
{ system ? builtins.currentSystem }:

let
  seed = import ../../bootstrap/seed.nix { inherit system; };
in
derivation {
  name = "sandbox";
  inherit system;
  builder = "${seed}/bin/bash";
  args = [ ./build.sh ];
  PATH = "${seed}/bin";
  sh = import ../../bootstrap/sh.nix { inherit system; };
}

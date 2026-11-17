# The builder VM's sandbox holds: a build sees no file system but the store
# and its own scratch directories, is not root, and has no network.
#
#   nix-build /bunix/nix/tests/sandbox/test.nix
let
  seed = import ../../seed.nix;
in
derivation {
  name = "sandbox";
  system = "aarch64-linux";
  builder = "${seed}/bin/bash";
  args = [ ./build.sh ];
  PATH = "${seed}/bin";
}

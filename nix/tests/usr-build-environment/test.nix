# The system builds itself: glibc is built again, with the system's own
# compiler and tools as its whole build environment, and no program of the
# bootstrap on PATH.
#
#   nix-build /bunix/nix/tests/usr-build-environment/test.nix
#
# The result has been the same, file for file, as the glibc of
# toolchain.nix, which stage 1's gcc and stage 2's tools built
# (`diff -r` of the two usr/).
{ system ? builtins.currentSystem }:

let
  stage1 = import ../../stage1.nix { inherit system; };
  stage2 = import ../../stage2.nix { inherit system; };
  tools = import ../../tools.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ../../sources.json);
  mkSystemPackage = import ../../system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    inherit (tools) buildEnvironment;
  };
in
mkSystemPackage {
  name = "glibc-by-the-system";
  source = sources.glibc;
  script = ../../toolchain/glibc.sh;
  env = { linux_headers = stage1.linuxHeaders; };
}

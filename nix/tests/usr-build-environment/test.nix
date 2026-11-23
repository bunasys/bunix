# The system builds itself: glibc is built again, with the system's own
# compiler and tools as its whole build environment and no program of the
# bootstrap on PATH, and comes out the same, file for file, as the one
# stage 1's gcc and stage 2's tools built (toolchain.nix).
#
#   nix-build /bunix/nix/tests/usr-build-environment/test.nix
{ system ? builtins.currentSystem }:

let
  stage1 = import ../../bootstrap/stage1.nix { inherit system; };
  stage2 = import ../../bootstrap/stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  tools = import ../../tools.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ../../sources.json);
  mkSystemPackage = import ../../system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
  };
  stagedBuild = import ../../stage.nix { inherit system; };

  builtByTheSystem = mkSystemPackage {
    name = "glibc-by-the-system";
    source = sources.glibc;
    script = ../../toolchain/glibc.sh;
    env = { linux_headers = stage1.linuxHeaders; };
  };
in
stagedBuild {
  name = "usr-build-environment";
  run = ./compare.sh;
  bootstrapTools = stage2.all;
  env = {
    by_the_bootstrap = toolchain.glibc;
    by_the_system = builtByTheSystem;
  };
}

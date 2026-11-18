# The system's gcc builds what a compiler is asked to, with no flags for
# where anything is, and nothing it builds names the store.
#
#   nix-build /bunix/nix/tests/usr-toolchain/test.nix
#
# The build is staged with the toolchain as /usr (stage.sh); stage 2's
# tools are on PATH after it, for the shell and the commands the test
# itself uses.
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  binDirectories = packages:
    builtins.concatStringsSep ":" (map (package: "${package}/bin") packages);
in
derivation {
  name = "usr-toolchain";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ../../stage.sh ];
  PATH = binDirectories (stage2.all ++ [ stage2.util-linux ]);
  toolsPath = binDirectories stage2.all;
  inside = ./build.sh;
  # gcc's `depends` file names glibc and binutils: all three are staged
  exportReferencesGraph = [ "closure-gcc" toolchain.gcc ];
  hello_c = ../hello.c;
  hello_cc = ../hello.cc;
}

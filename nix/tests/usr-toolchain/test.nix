# The system's gcc builds what a compiler is asked to, with no flags for
# where anything is, and nothing it builds names the store.
#
#   nix-build /bunix/nix/tests/usr-toolchain/test.nix
#
# The build is staged with the toolchain as /usr; stage 2's tools are on
# PATH after it, for the shell and the commands the test itself uses.
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../bootstrap/stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  stagedBuild = import ../../stage.nix { inherit system; };
in
stagedBuild {
  name = "usr-toolchain";
  run = ./build.sh;
  # gcc's `depends` file names glibc and binutils: all three are staged
  buildDepends = [ toolchain.gcc ];
  bootstrapTools = stage2.all;
  env = {
    hello_c = ../hello.c;
    hello_cc = ../hello.cc;
  };
}

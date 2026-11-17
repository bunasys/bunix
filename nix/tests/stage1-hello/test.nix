# Stage 1's gcc builds programs for stage 1's glibc with no flags at all,
# and nothing of the seed is in them.
#
#   nix-build /bunix/nix/tests/stage1-hello/test.nix
#
# The seed is still on PATH, last, for the shell and the tools the test
# itself uses; the compiler and the linker are stage 1's.
{ system ? builtins.currentSystem }:

let
  seed = import ../../seed.nix { inherit system; };
  stage1 = import ../../stage1.nix { inherit system; };
in
derivation {
  name = "stage1-hello";
  inherit system;
  builder = "${seed}/bin/bash";
  args = [ ./build.sh ];
  PATH = "${stage1.gcc}/bin:${stage1.binutils}/bin:${seed}/bin";
  inherit seed;
  glibc = stage1.glibc;
  hello_c = ../hello.c;
  hello_cc = ../hello.cc;
}

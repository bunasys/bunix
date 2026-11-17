# The seed works inside a Nix build: it compiles C and C++ programs, static
# and dynamic, and they run, with nothing but the seed to build them.
#
#   nix-build /bunix/nix/tests/seed-hello/test.nix
#
# Every attribute below reaches build.sh as an environment variable; a path
# (../hello.c) is first copied into the store and arrives as its store path.
{ system ? builtins.currentSystem }:

let
  seed = import ../../seed.nix { inherit system; };
in
derivation {
  name = "seed-hello";
  inherit system;
  builder = "${seed}/bin/bash";
  args = [ ./build.sh ];
  PATH = "${seed}/bin";
  inherit seed;
  hello_c = ../hello.c;
  hello_cc = ../hello.cc;
}

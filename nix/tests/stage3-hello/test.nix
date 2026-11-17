# Stage 3's gcc builds what a real compiler is asked to, with no flags for
# where anything is, and what it builds needs glibc and gcc's libraries to
# run: not the compiler, and nothing from an earlier stage.
#
#   nix-build /bunix/nix/tests/stage3-hello/test.nix
{ system ? builtins.currentSystem }:

let
  seed = import ../../seed.nix { inherit system; };
  stage1 = import ../../stage1.nix { inherit system; };
  stage2 = import ../../stage2.nix { inherit system; };
  stage3 = import ../../stage3.nix { inherit system; };
  tools = [ stage3.gcc stage3.binutils ] ++ stage2.all;
in
derivation {
  name = "stage3-hello";
  inherit system;
  builder = "${stage2.bash}/bin/bash";
  args = [ ./build.sh ];
  PATH = builtins.concatStringsSep ":" (map (tool: "${tool}/bin") tools);
  glibc = stage3.glibc;
  hello_c = ../hello.c;
  hello_cc = ../hello.cc;

  # Nix fails the build if the result needs any of these to run.
  disallowedRequisites =
    [ stage3.gcc stage3.binutils seed stage1.glibc stage1.binutils stage1.gcc ] ++ stage2.all;
}

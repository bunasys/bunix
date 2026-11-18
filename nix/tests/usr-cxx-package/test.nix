# A package with a C++ program needs gcc's libraries to run, and not gcc:
# it declares gccLibraries, is built with gcc staged only for the build,
# and Nix fails it if the compiler is among what it needs.
#
#   nix-build /bunix/nix/tests/usr-cxx-package/test.nix
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  mkSystemPackage = import ../../system-package.nix {
    inherit system;
    shell = "${stage2.bash}/bin/bash";
    stagingTools = stage2.all ++ [ stage2.util-linux ];
    bootstrapTools = stage2.all;
  };
in
mkSystemPackage {
  name = "usr-cxx-package";
  version = "1";
  script = ./build.sh;
  depends = [ toolchain.glibc toolchain.gccLibraries ];
  buildDepends = [ toolchain.gcc ];
  env = {
    hello_cc = ../hello.cc;
    disallowedRequisites = [ toolchain.gcc toolchain.gccWhole toolchain.binutils ];
  };
}

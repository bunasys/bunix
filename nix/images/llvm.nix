# The llvm extension: what software is built with on a running system --
# clang and LLVM's linker and tools, make, patch, pkgconf, cmake, meson
# and ninja.  After x86's gcc extension
# (elements/sysext/gcc-content.bst), with clang where that has gcc.
#
#   nix-build /bunix/nix/images/llvm.nix -A image
#
# The headers and start files of the C library, and of the system's own
# libraries, are not here: this system has them (an image is of whole
# packages, images/system.nix).
#
# clangSetup: what clang takes from gcc on Linux, and cannot do without,
# and its setting to link with LLVM's linker (toolchain/clang-setup.sh).
# A program built here uses the system's libstdc++, as every C++ program
# of the system does.
#
# binutils, for the tools a build calls by their plain names (ar, ranlib,
# strip, as).
#
# Not here, and what does not work for it: LLVM's own runtime libraries
# (compiler-rt), so no sanitizers (-fsanitize=), no coverage, no OpenMP;
# and the static C++ library.
#
#   signature, version
#           as images/extension.nix takes them
{ system ? builtins.currentSystem, signature ? null, version ? import ../release.nix }:

let
  toolchain = import ../toolchain.nix { inherit system; };
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  extension = import ./extension.nix { inherit system signature version; };
in
extension {
  name = "llvm";
  contents = [
    base.llvm toolchain.clangSetup toolchain.binutils
    tools.make tools.patch base.pkgconf base.cmake base.meson base.ninja
  ];
  # the C++ library's headers (clangSetup)
  keep = [ "include/c++" ];
  # the names a build asks for a compiler by, when it is told of none
  links = [ "bin/cc=clang" "bin/c++=clang++" ];
}

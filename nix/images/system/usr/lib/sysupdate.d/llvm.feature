# What software is built with, as a system extension: clang and LLVM's
# tools, make, patch, pkgconf, cmake, meson and ninja (images/llvm.nix;
# after files/rootfs's gcc.feature).  It needs no other extension.
#
#   bunix ext enable llvm
[Feature]
Description=Compiler and build tools (clang, lld, make, cmake, meson, ninja)
Enabled=false

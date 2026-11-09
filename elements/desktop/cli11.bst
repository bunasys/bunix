kind: cmake
description: |
  CLI11 -- a header-only C++ command-line parser: Quickshell's `qs`
  options (desktop/quickshell.bst).  Build-time only.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

sources:
- kind: tar
  url: github:CLIUtils/CLI11/archive/refs/tags/v2.7.2.tar.gz
  ref: 46eef3101da70852ec7af026e09d485ccee81813331c8c6052d39344443b83da

variables:
  cmake-local: >-
    -DCLI11_BUILD_TESTS=OFF
    -DCLI11_BUILD_EXAMPLES=OFF
    -DCLI11_BUILD_DOCS=OFF

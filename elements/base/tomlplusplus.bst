kind: meson
description: |
  toml++ -- a TOML parser in C++ headers (hyprcursor's theme manifests)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
# its meson build also writes a cmake package file
- base/cmake.bst

sources:
- kind: tar
  url: github:marzer/tomlplusplus/archive/refs/tags/v3.4.0.tar.gz
  ref: 8517f65938a4faae9ccf8ebb36631a38c1cadfb5efa85d9a72e15b9e97d25155

variables:
  meson-local: -Dbuild_tests=false -Dbuild_examples=false

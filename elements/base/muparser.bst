kind: cmake
description: |
  muParser -- a math expression parser (Hyprland's configuration expressions)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:beltoforion/muparser/archive/refs/tags/v2.3.5.tar.gz
  ref: 20b43cc68c655665db83711906f01b20c51909368973116dfc8d7b3c4ddb5dd4

variables:
  cmake-local: -DENABLE_SAMPLES=OFF -DENABLE_OPENMP=OFF -DBUILD_TESTING=OFF

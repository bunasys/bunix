kind: cmake
description: |
  RE2 -- regular expressions in linear time (Hyprland's window rules)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/abseil.bst

sources:
- kind: tar
  url: github:google/re2/releases/download/2025-11-05/re2-2025-11-05.tar.gz
  ref: 87f6029d2f6de8aa023654240a03ada90e876ce9a4676e258dd01ea4c26ffd67

variables:
  cmake-local: -DBUILD_SHARED_LIBS=ON -DRE2_BUILD_TESTING=OFF -DRE2_USE_ICU=OFF

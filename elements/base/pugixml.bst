kind: cmake
description: |
  pugixml -- an XML parser (hyprwayland-scanner reads protocol XML with it)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:zeux/pugixml/releases/download/v1.16/pugixml-1.16.tar.gz
  ref: 4cee1ca4aad395170f4c7a07824f3bdd41f28316c6e1e1090a1425b278ec0b4b

variables:
  cmake-local: -DBUILD_SHARED_LIBS=ON -DPUGIXML_BUILD_TESTS=OFF

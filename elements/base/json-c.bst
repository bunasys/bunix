kind: cmake
description: json-c -- the JSON library cryptsetup keeps its metadata in

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

sources:
- kind: tar
  url: github:json-c/json-c/archive/refs/tags/json-c-0.19-20260627.tar.gz
  ref: f17a6d7d265cf840dfd8f0f46a606d98c6b5b26dc7cfe27275d1546a213086c8

variables:
  cmake-local: -DBUILD_STATIC_LIBS=OFF -DBUILD_TESTING=OFF -DDISABLE_WERROR=ON

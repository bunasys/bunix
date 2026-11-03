kind: cmake
description: libuv -- the event loop library BIND uses

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

sources:
- kind: tar
  url: libuv:v1.53.0/libuv-v1.53.0.tar.gz
  ref: cb0d6dd2128d5a95bd242c6cc982a24fe608fa93da57b6b4ec763b0018c53e64

variables:
  cmake-local: -DBUILD_TESTING=OFF -DLIBUV_BUILD_SHARED=ON

config:
  install-commands:
    (>):
    - rm %{install-root}%{libdir}/libuv.a

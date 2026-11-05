kind: cmake
description: |
  Abseil -- Google's C++ library, which RE2 is built on

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:abseil/abseil-cpp/releases/download/20260817.0/abseil-cpp-20260817.0.tar.gz
  ref: f7e05179df39c45434cad433f5783840bb3788ef322976f9138bc6b72b3a107d

variables:
  cmake-local: -DBUILD_SHARED_LIBS=ON -DABSL_PROPAGATE_CXX_STD=ON -DCMAKE_CXX_STANDARD=17 -DABSL_BUILD_TESTING=OFF

kind: cmake
description: |
  glaze -- JSON reading and writing in C++ headers (Hyprland's IPC)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:stephenberry/glaze/archive/refs/tags/v7.2.0.tar.gz
  ref: 17dba19ae63ae48f94994f00d49d5cb3c8f1306db1046c534c4828662490b7d4

variables:
  cmake-local: -Dglaze_DEVELOPER_MODE=OFF -DBUILD_TESTING=OFF -Dglaze_ENABLE_FUZZING=OFF

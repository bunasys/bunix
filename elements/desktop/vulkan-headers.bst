kind: cmake
description: |
  Vulkan-Headers -- the Vulkan API's C headers, and nothing else: Qt's
  Vulkan API (desktop/qt6-base.bst) and Quickshell's DMA-BUF buffers
  (desktop/quickshell.bst) are built with them.  Headers only: the
  desktop extension drops them (sysext/desktop-tree.bst), and bunix has no
  Vulkan loader.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

sources:
- kind: tar
  url: github:KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.4.368.tar.gz
  ref: 5c5c6f64fcce28a24cc934143a048707af036a858e4ed11d7f71fe016006ecda

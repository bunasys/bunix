kind: stack
description: |
  What the devel extension is made from: the toolchain and the tools
  software is commonly built with, and the base packages, whose headers,
  pkg-config files and static libraries system/rootfs.bst leaves out.
  sysext/devel-tree.bst keeps only what the root file system does not have.

depends:
- bootstrap/toolchain.bst
- base/linux-headers.bst
- base/make.bst
- base/pkgconf.bst
- base/m4.bst
- base/autoconf.bst
- base/automake.bst
- base/libtool.bst
- base/cmake.bst
- base/meson.bst
- base/ninja.bst
- base.bst

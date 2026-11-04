kind: autotools
description: |
  GNU diffutils -- diff, cmp, diff3, sdiff: for the gcc extension
  (sysext/gcc-content.bst), since configure scripts and test suites call them

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:diffutils/diffutils-3.12.tar.xz
  ref: 7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd

variables:
  conf-local: --disable-nls

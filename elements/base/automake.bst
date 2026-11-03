kind: autotools
description: GNU automake -- generates Makefile.in files for autoconf projects

build-depends:
- bootstrap/build-env.bst

depends:
- base/autoconf.bst

sources:
- kind: tar
  url: gnu:automake/automake-1.19.tar.xz
  ref: e3e2c2e3abf37898138db5b6c1d1dc35c9160c5978be7947d2c741705251d445

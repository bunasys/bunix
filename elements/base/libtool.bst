kind: autotools
description: GNU libtool -- shared-library support for autoconf projects

build-depends:
- bootstrap/build-env.bst

depends:
- base/m4.bst

sources:
- kind: tar
  url: gnu:libtool/libtool-2.6.2.tar.xz
  ref: 2ef1067c16c97db930fd740cc9bc3d3ba9a583804ae5ac42cc3e8719e49e191e

variables:
  conf-local: --disable-static

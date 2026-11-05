kind: autotools
description: |
  libogg -- the Ogg container (libvorbis, for libcanberra's event sounds)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: https://downloads.xiph.org/releases/ogg/libogg-1.3.6.tar.xz
  ref: 5c8253428e181840cd20d41f3ca16557a9cc04bad4a3d04cce84808677fa1061

variables:
  conf-local: --disable-static

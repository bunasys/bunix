kind: autotools
description: |
  libvorbis -- the Vorbis audio codec (libcanberra's event sounds)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libogg.bst

sources:
- kind: tar
  url: https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.xz
  ref: b33cc4934322bcbf6efcbacf49e3ca01aadbea4114ec9589d1b1e9d20f72954b

variables:
  conf-local: --disable-static

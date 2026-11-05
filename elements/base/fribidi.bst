kind: meson
description: |
  GNU FriBidi -- the Unicode bidirectional algorithm: Arabic and Hebrew
  laid out right to left (pango)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:fribidi/fribidi/releases/download/v1.0.18/fribidi-1.0.18.tar.xz
  ref: 1de5e8073d035388b71d0b2d452b1da1f8caeea8a7702997b401fe1b6250727f

variables:
  meson-local: -Ddocs=false -Dbin=false -Dtests=false -Ddeprecated=false

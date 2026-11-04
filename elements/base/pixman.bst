kind: meson
description: pixman -- pixel compositing on the CPU (cairo, foot, the compositor's fallbacks)

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: https://www.cairographics.org/releases/pixman-0.46.4.tar.gz
  ref: d09c44ebc3bd5bee7021c79f922fe8fb2fb57f7320f55e97ff9914d2346a591c

variables:
  meson-local: -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled -Dopenmp=disabled

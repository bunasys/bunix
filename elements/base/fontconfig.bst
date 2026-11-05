kind: meson
description: |
  Fontconfig -- finds fonts by name, language and style for every program
  that draws text; its cache is built when the system image is put
  together, since /usr is read-only

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gperf.bst

depends:
- base/freetype.bst
- base/expat.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/api/v4/projects/890/packages/generic/fontconfig/2.18.3/fontconfig-2.18.3.tar.xz
  ref: 4f7b554a38cdf78c033f666c8871f3749e14a094f65a07f630c91ed0b43d35e3

variables:
  meson-local: >-
    -Ddoc=disabled -Dnls=disabled -Dtests=disabled -Dtools=enabled
    -Dcache-build=disabled -Dxml-backend=expat -Dcache-dir=/var/cache/fontconfig
    -Dbaseconfig-dir=/usr/share/fontconfig -Dconfig-dir=/usr/share/fontconfig/conf.d

kind: meson
description: |
  FreeType -- reads and renders font files.  Without HarfBuzz, which is
  built on FreeType (base/harfbuzz.bst): FreeType would use it only to
  auto-hint fonts that lack hints, and the two would depend on each other.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/zlib.bst
- base/bzip2.bst
- base/libpng.bst

sources:
- kind: tar
  url: https://download.savannah.gnu.org/releases/freetype/freetype-2.15.0.tar.xz
  ref: 93cd47eb719c325107f2d3cf087d06299e944c3b48a40b55537302304dea1dd5

variables:
  meson-local: -Dharfbuzz=disabled -Dbrotli=disabled -Dpng=enabled -Dbzip2=enabled -Dzlib=system -Dtests=disabled

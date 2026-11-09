kind: cmake
description: |
  Qt 6 SVG -- SVG images and icons in Qt Quick; without it DMS's icons
  (most of them SVG) do not show.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- desktop/qt6-base.bst

sources:
- kind: tar
  url: qt:6.12/6.12.0/submodules/qtsvg-everywhere-src-6.12.0.tar.xz
  ref: e4ab39534ec97987b1b9b60ef7f4d3253d5912a69f8c713a01753174a4029331

variables:
  cmake-local: -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF

config:
  install-commands:
    (>):
    # the plugin that loads SVG images: without it DMS shows no icons
    - test -f %{install-root}%{prefix}/%{lib}/qt6/plugins/imageformats/libqsvg.so

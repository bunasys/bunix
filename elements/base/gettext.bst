kind: autotools
description: |
  GNU gettext -- the translation tools (xgettext, msgfmt, ...): every
  translated part of the system (Arabic and English, docs/desktop.md) goes
  through them.  glibc has the run-time side (libintl) already.

build-depends:
- bootstrap/build-env.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: gnu:gettext/gettext-1.0.tar.xz
  ref: 71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7

variables:
  conf-local: >-
    --disable-static --disable-java --disable-csharp --disable-d
    --disable-modula2 --disable-go --disable-openmp --disable-rpath

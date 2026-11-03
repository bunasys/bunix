kind: meson
description: |
  xkeyboard-config -- the keyboard layouts (Arabic and English among them)
  that xkbcommon reads: data only

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
# writes the layout lists (rules/xml2lst.pl)
- base/perl.bst

sources:
- kind: tar
  url: xorg:individual/data/xkeyboard-config/xkeyboard-config-2.48.tar.xz
  ref: b77041324f0109f77161ee43743fe04baa485866af8460d31e476ad3f7648fd5

variables:
  # nls would translate the layouts' descriptions, which needs gettext
  meson-local: -Dnls=false -Dxorg-rules-symlinks=true

kind: autotools
description: |
  hwdata -- hardware ID lists.  Only pnp.ids, the display makers' IDs
  that niri's built-in libdisplay-info names screens with; needed only to
  build niri (lspci and lsusb have their own lists).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:vcrhonek/hwdata/archive/refs/tags/v0.413.tar.gz
  ref: 5a71ab7a48c668ef912fcfdbec046949087019f8dd7fb967445d36fbeb778350

config:
  install-commands:
    (>):
    - |
      cd %{install-root}%{datadir}/hwdata
      find . -type f ! -name pnp.ids -delete

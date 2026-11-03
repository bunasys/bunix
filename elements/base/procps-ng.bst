kind: autotools
description: |
  procps-ng -- ps, top, free, pgrep/pkill, pidof, sysctl, uptime, vmstat,
  watch, w.  kill comes from util-linux, as on most distributions.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: sourceforge:procps-ng/Production/procps-ng-4.0.7.tar.xz
  ref: 9d2021f47a4501c667862c9942a92d1953694b21d11bcd1702e83eb594e3d67d

variables:
  conf-local: >-
    --disable-static --disable-nls --disable-kill --without-systemd
    --enable-watch8bit

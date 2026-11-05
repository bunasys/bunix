kind: meson
description: |
  seatd and libseat -- give the compositor the screens and input devices
  without running it as root.  In a login session libseat asks logind;
  seatd's own daemon (seatd-launch) is for starting a compositor outside
  one, as root from a console.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/systemd.bst

sources:
- kind: tar
  url: https://git.sr.ht/~kennylevinsen/seatd/archive/0.9.3.tar.gz
  ref: 302564d54d8e28191fadfd734f2675ecb0c9e0615a58011b89ef15dfa4dbaa96

variables:
  meson-local: >-
    -Dlibseat-logind=systemd -Dlibseat-seatd=enabled -Dlibseat-builtin=enabled
    -Dserver=enabled -Dexamples=disabled -Dman-pages=disabled

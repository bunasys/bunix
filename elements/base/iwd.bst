kind: autotools
description: |
  iwd -- the wireless daemon: scans, authenticates (WPA2/WPA3/Enterprise) and
  keeps the link up, leaving IP configuration to networkd.  iwctl is its
  client.  The chips' firmware is system/firmware.bst.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/readline.bst

runtime-depends:
- base/dbus.bst

sources:
- kind: tar
  url: kernel:linux/network/wireless/iwd-3.12.tar.xz
  ref: d89a5e45c7180170e19be828f9e944a768c593758094fc57a358d0e7c4cb1a49

variables:
  # the release tarball carries its own copy of ell, used by default; the
  # manual pages would need rst2man
  conf-local: >-
    --enable-client --disable-manual-pages --enable-systemd-service
    --with-systemd-unitdir=/usr/lib/systemd/system
    --with-systemd-networkdir=/usr/lib/systemd/network
    --with-systemd-modloaddir=/usr/lib/modules-load.d
    --with-dbus-datadir=/usr/share
    --with-dbus-busdir=/usr/share/dbus-1/system-services

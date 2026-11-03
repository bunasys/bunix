kind: meson
description: |
  D-Bus -- the system bus.  iwd needs it outright; resolvectl and networkctl
  talk to their daemons over it.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

# dbus-daemon links libsystemd for socket activation and journal logging
depends:
- base/expat.bst
- base/systemd.bst

sources:
- kind: tar
  url: dbus:dbus/dbus-1.16.2.tar.xz
  ref: 0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2

variables:
  # its setuid helper (dbus-daemon-launch-helper) gets a directory of its own
  libexecdir: "%{prefix}/lib/dbus-1.0"
  meson-local: >-
    -Dsystemd=enabled -Dsystemd_system_unitdir=/usr/lib/systemd/system
    -Dmessage_bus=true -Dtools=true -Duser_session=false
    -Dselinux=disabled -Dapparmor=disabled -Dlibaudit=disabled
    -Dx11_autolaunch=disabled -Dmodular_tests=disabled -Dinstalled_tests=false
    -Ddoxygen_docs=disabled -Dducktype_docs=disabled -Dxml_docs=disabled
    -Dqt_help=disabled

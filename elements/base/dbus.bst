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
  url: dbus:dbus/dbus-1.16.4.tar.xz
  ref: d08b05526c2cb7966a5fb79210d6112b1aca3d135f315c1b302e14b4b0297dac

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

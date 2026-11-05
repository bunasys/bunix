kind: manual
description: |
  The session bus: the D-Bus bus each logged-in user's own services and
  apps talk over (WirePlumber, the screen-sharing portal, GTK apps).
  dbus-daemon and session.conf are the base's (base/dbus.bst, built
  without its per-user units); these are those two units, made from the
  same dbus source, for the desktop extension, and started with the user's
  session (sockets.target).

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: dbus:dbus/dbus-1.16.2.tar.xz
  ref: 0ba2a1a4b16afe7bceb2c07e9ce99a8c2c3508e5dec290dbb643384bd6beb7e2

config:
  install-commands:
  - |
    units=%{install-root}/usr/lib/systemd/user
    mkdir -p $units/sockets.target.wants
    for unit in dbus.service dbus.socket; do
      sed -e 's|@EXPANDED_BINDIR@|%{bindir}|g' -e 's|@SYSTEMCTL@|%{bindir}/systemctl|g' \
        bus/systemd-user/$unit.in > $units/$unit
    done
    ln -s ../dbus.socket $units/sockets.target.wants/dbus.socket
    if grep -n '@' $units/dbus.service $units/dbus.socket; then exit 1; fi

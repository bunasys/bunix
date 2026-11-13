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
  url: dbus:dbus/dbus-1.16.4.tar.xz
  ref: d08b05526c2cb7966a5fb79210d6112b1aca3d135f315c1b302e14b4b0297dac

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

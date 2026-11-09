kind: meson
description: |
  AccountsService -- a D-Bus service that lists the people who can log in
  and keeps their display name, picture and language
  (org.freedesktop.Accounts).  DMS's login screen (desktop/dms-greeter.bst)
  takes its list of users from it, and DMS (desktop/dms.bst) the profile
  picture and name in its bar.

  Its daemon is started at boot, upheld by multi-user.target (docs/desktop.md,
  "Units in an extension"), as every service of the desktop extension is,
  rather than on its first D-Bus call: its list of users is then ready when
  the login screen draws.  Administrators are the wheel group, as for polkit
  (base/polkit.bst).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gettext.bst

depends:
- base/glib.bst
- base/polkit.bst
- base/dbus.bst
- base/systemd.bst
- base/libxcrypt.bst

sources:
- kind: tar
  url: freedesktop:accountsservice/accountsservice-23.13.9.tar.xz
  ref: adda4cdeae24fa0992e7df3ffff9effa7090be3ac233a3edfdf69d5a9c9b924f

variables:
  meson-local: >-
    -Dintrospection=false
    -Dvapi=false
    -Dadmin_group=wheel
    -Dsystemdsystemunitdir=%{prefix}/lib/systemd/system

config:
  configure-commands:
    (<):
    # Its version comes from the source directory's name (or from git),
    # which the sandbox's directory does not carry: say it outright
    - printf '#!/bin/sh\necho 23.13.9\n' > generate-version.sh
    # No tests: they need mocklibc, which no longer compiles (GCC 16), and
    # nothing turns them off but leaving them out
    - |
      sed -i "/^subdir('tests')$/d" meson.build
      if grep -q "subdir('tests')" meson.build; then exit 1; fi

  install-commands:
    (>):
    - |
      units=%{install-root}%{prefix}/lib/systemd/system
      # Its sandbox names paths that must all exist, or the service does
      # not start (226/NAMESPACE): bunix has no /var/log/wtmp (no utmp in
      # systemd), the interfaces directory is never installed, and logind's
      # seats appear only once logind runs.  Optional ("-") here, and it
      # starts after logind.
      unit=$units/accounts-daemon.service
      sed -i -e 's#^\(  \)\(/var/log/wtmp\|/usr/share/accountsservice/interfaces/\|/run/systemd/seats/\)#\1-\2#' \
             -e 's#^After=nss-user-lookup.target$#After=nss-user-lookup.target systemd-logind.service#' $unit
      grep -q '^  -/var/log/wtmp ' $unit
      grep -q '^  -/usr/share/accountsservice/interfaces/ ' $unit
      grep -q '^  -/run/systemd/seats/$' $unit
      grep -q '^After=nss-user-lookup.target systemd-logind.service$' $unit
      mkdir -p $units/multi-user.target.d
      cat > $units/multi-user.target.d/accountsservice.conf <<'UNIT'
      [Unit]
      Upholds=accounts-daemon.service
      UNIT

kind: meson
description: |
  WirePlumber -- PipeWire's session manager: finds the sound cards, picks
  the output (speakers, headphones when plugged in), remembers volumes,
  and lets apps in; wpctl sets volumes from the command line.  Its policy
  is in Lua, the system's (base/lua.bst).  Started with PipeWire.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gettext.bst

depends:
- base/glib.bst
- base/lua.bst
- base/pipewire.bst
- base/systemd.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/pipewire/wireplumber/-/archive/0.5.19/wireplumber-0.5.19.tar.bz2
  ref: e743070200e3788b8a46b5cd35438170dea4458302cfa3bb04ab4a9495ad14a4

variables:
  meson-local: >-
    -Dsystem-lua=true -Dsystemd=enabled -Dsystemd-user-service=true
    -Dsystemd-system-service=false -Delogind=disabled
    -Dintrospection=disabled -Ddoc=disabled -Dtests=false -Ddbus-tests=false

config:
  install-commands:
    (>):
    - |
      # Started with PipeWire, and named as its session manager (what
      # systemctl --user --global enable does, written into /usr)
      units=%{install-root}/usr/lib/systemd/user
      mkdir -p $units/pipewire.service.wants
      ln -s ../wireplumber.service $units/pipewire.service.wants/wireplumber.service
      ln -s wireplumber.service $units/pipewire-session-manager.service

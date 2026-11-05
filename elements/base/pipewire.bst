kind: meson
description: |
  PipeWire -- the desktop's sound server: mixes every app's sound onto the
  card (ALSA), with a PulseAudio-compatible server (pipewire-pulse) for
  apps written for PulseAudio, and an ALSA plugin that makes it ALSA's
  default device, so programs using ALSA directly mix through it too.
  Video streams too, for screen sharing (the desktop portal).  Runs as
  each user's own service (systemd --user), started with the session.
  Without Bluetooth (with BlueZ, later), JACK, cameras, and real-time
  priority (its limits file belongs in /etc/security, which an extension
  cannot carry).

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
- base/gettext.bst

depends:
- base/alsa-lib.bst
- base/dbus.bst
- base/readline.bst
- base/systemd.bst

sources:
- kind: tar
  url: https://gitlab.freedesktop.org/pipewire/pipewire/-/archive/1.6.11/pipewire-1.6.11.tar.bz2
  ref: 0b32fbbece4591376b45dde5a818bfa5b3517e70913a2f7414e33c47c20b07ee

variables:
  # Every optional feature starts disabled; the ones below are what the
  # desktop uses.  (Options whose default is "enabled", not "auto", are
  # turned off by name.)
  meson-local: >-
    -Dauto_features=disabled
    -Dlibsystemd=enabled -Dlogind=enabled -Dsystemd-user-service=enabled -Dudev=enabled
    -Ddbus=enabled -Dreadline=enabled
    -Dspa-plugins=enabled -Dalsa=enabled -Dpipewire-alsa=enabled
    -Daudiomixer=enabled -Daudioconvert=enabled -Dsupport=enabled -Dcontrol=enabled
    -Dvideoconvert=enabled
    -Dpipewire-jack=disabled -Dpipewire-v4l2=disabled -Dflatpak=disabled
    -Daudiotestsrc=disabled -Dvideotestsrc=disabled
    -Dexamples=disabled -Dtests=disabled -Ddocs=disabled -Dman=disabled
    -Dsession-managers=[] -Drlimits-install=false -Dlegacy-rtkit=false

config:
  install-commands:
    (>):
    - |
      # Started with each user's session: the sockets, which start the
      # services on first use (systemctl --user --global enable, written
      # into /usr)
      units=%{install-root}/usr/lib/systemd/user
      mkdir -p $units/sockets.target.wants
      ln -s ../pipewire.socket $units/sockets.target.wants/pipewire.socket
      ln -s ../pipewire-pulse.socket $units/sockets.target.wants/pipewire-pulse.socket
      ls $units

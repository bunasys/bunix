kind: autotools
description: |
  alsa-utils -- alsactl, which sets the sound card's volumes at boot
  (unmuted, at ALSA's defaults the first time, as they were left after
  that), and amixer, aplay and speaker-test.  Without alsamixer's
  interface, the BAT tester and the man pages.  Part of the desktop
  extension, so upstream's udev rule is left out (the card appears before
  the extension is merged), and alsactl runs from a unit of its own.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/alsa-lib.bst

sources:
- kind: tar
  url: https://www.alsa-project.org/files/pub/utils/alsa-utils-1.2.16.tar.bz2
  ref: 092399d5e8749a1d5e188e393157521cec4b75693b60ebb79bbce728cff2232c

variables:
  conf-local: >-
    --disable-nls --disable-alsamixer --disable-bat --disable-alsaconf --disable-alsaloop
    --disable-xmlto --disable-rst2man --with-asound-state-dir=/var/lib/alsa

config:
  install-commands:
    (>):
    - rm -rf %{install-root}/usr/lib/udev %{install-root}/usr/lib/systemd
    - |
      # The volumes at boot and shutdown.  alsactl restore uses ALSA's
      # defaults (unmuted) when nothing was saved yet.
      units=%{install-root}/usr/lib/systemd/system
      mkdir -p $units/multi-user.target.d
      cat > $units/alsa-restore.service <<'UNIT'
      [Unit]
      Description=Sound card volumes
      After=systemd-sysext.service
      ConditionPathExistsGlob=/dev/snd/control*

      [Service]
      Type=oneshot
      RemainAfterExit=yes
      ExecStart=-/usr/bin/alsactl restore
      ExecStop=-/usr/bin/alsactl store
      UNIT
      # Upholds=, not a .wants link: the extension's units arrive after the
      # boot has decided what to start, and Upholds= starts the unit
      # whenever it is not running
      cat > $units/multi-user.target.d/alsa-restore.conf <<'UNIT'
      [Unit]
      Upholds=alsa-restore.service
      UNIT

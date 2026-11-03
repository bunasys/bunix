kind: meson
description: |
  Plymouth -- the boot splash: the Buna logo from the initrd until the
  system is up (files/plymouth/bunix, docs/desktop.md phase 1).  Draws
  through DRM/KMS, so the firmware's framebuffer (simpledrm) is enough; a
  GPU driver, once there is one, takes over without a flicker.

  Without pango and freetype: the splash shows no text yet (Arabic text
  needs pango); passwords are asked on the text console.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst
# msgfmt, for the themes' translated titles
- base/gettext.bst
# for systemd.pc (the unit directory) and systemd-tty-ask-password-agent
- base/systemd.bst

depends:
- base/libpng.bst
- base/libdrm.bst
- base/libevdev.bst
- base/libxkbcommon.bst

sources:
- kind: tar
  url: freedesktop:plymouth/releases/plymouth-26.134.222.tar.xz
  ref: 6ee1068216c5047923fabf0f6aa583e9d77cab383077358df3fc22f2ee398bb0
- kind: local
  path: files/plymouth
  directory: bunix-theme

variables:
  meson-local: >-
    -Dpango=disabled -Dfreetype=disabled -Dgtk=disabled -Ddocs=false
    -Dudev=enabled -Dsystemd-integration=true -Dupstart-monitoring=false
    -Dtracing=false -Drelease-file=/usr/lib/os-release
    -Dbackground-color=0x000000 -Dbackground-start-color-stop=0x000000
    -Dbackground-end-color-stop=0x000000

config:
  configure-commands:
    (<):
    # Plymouth takes its version from the name of its source directory,
    # which here is the element's
    - printf '#!/bin/sh\necho 26.134.222\n' > scripts/generate-version.sh

  install-commands:
    (>):
    - |
      # The bunix theme: the spinner theme's pictures with the logo as its
      # watermark.  The other themes go; details and text stay as the
      # fallbacks Plymouth uses when it cannot draw pictures.
      themes=%{install-root}/usr/share/plymouth/themes
      mkdir -p $themes/bunix
      cp $themes/spinner/*.png $themes/bunix/
      cp bunix-theme/bunix/bunix.plymouth bunix-theme/bunix/watermark.png $themes/bunix/
      for theme in $themes/*; do
        case ${theme##*/} in bunix|details|text) ;; *) rm -rf "$theme" ;; esac
      done
      sed -i 's/^Theme=.*/Theme=bunix/' %{install-root}/usr/share/plymouth/plymouthd.defaults
      grep Theme= %{install-root}/usr/share/plymouth/plymouthd.defaults

kind: meson
description: |
  Linux-PAM -- how login, run0, greetd and systemd's user manager check
  passwords and open sessions (pam_systemd registers them with logind:
  seats, /run/user/<uid>, user services).  Its modules only; bunix's rules
  are files/rootfs/usr/lib/pam.d, which PAM reads after /etc/pam.d, so an
  update brings new defaults and an admin's own files still win.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/libxcrypt.bst

sources:
- kind: tar
  url: github:linux-pam/linux-pam/releases/download/v1.7.3/Linux-PAM-1.7.3.tar.xz
  ref: 2ce4765fd49df6693771ef2941f81e33d8ee14b94a81a5c7b369aa3b137b85a5

variables:
  # logind off: it is for two modules this system does not use, and
  # systemd (logind) is built on PAM, not the other way round
  meson-local: >-
    -Di18n=disabled -Ddocs=disabled -Daudit=disabled -Deconf=disabled
    -Dlogind=disabled -Delogind=disabled -Dselinux=disabled -Dnis=disabled
    -Dpwaccess=disabled -Dpam_userdb=disabled -Dexamples=false -Dxtests=false

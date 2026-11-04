kind: autotools
description: |
  cryptsetup -- libcryptsetup, which systemd uses to set up dm-verity for
  /usr and the system extension images, and the cryptsetup and veritysetup
  programs, to open, inspect and check encrypted and verity volumes by
  hand.  Without integritysetup.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
# the programs' option parsing
- base/popt.bst
- base/device-mapper.bst
- base/json-c.bst
- base/openssl.bst
- base/util-linux.bst

sources:
- kind: tar
  url: kernel:linux/utils/cryptsetup/v2.8/cryptsetup-2.8.8.tar.xz
  ref: 3acfa685f2dd7fcc832e0b77bc7093aa7da554a51ce8dafbb4138eaa854eee35

variables:
  # No udev: libudev is part of systemd, which is built after this.
  conf-local: >-
    --disable-static --disable-nls --disable-asciidoc
    --disable-integritysetup
    --disable-ssh-token --disable-external-tokens --disable-udev
    --disable-selinux --with-crypto_backend=openssl

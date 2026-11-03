kind: autotools
description: |
  libcryptsetup -- systemd uses it to set up dm-verity for system extension
  images.  Only the library: the cryptsetup, veritysetup and integritysetup
  programs are not built.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/popt.bst

depends:
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
    --disable-cryptsetup --disable-veritysetup --disable-integritysetup
    --disable-ssh-token --disable-external-tokens --disable-udev
    --disable-selinux --with-crypto_backend=openssl

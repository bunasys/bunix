kind: autotools
description: |
  GNU tar, in place of BusyBox's: --zstd and the other compressors,
  extended attributes, sparse files, and the options scripts expect

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:tar/tar-1.35.tar.xz
  ref: 4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16

variables:
  # FORCE_UNSAFE_CONFIGURE: configure refuses to run as root, which the
  # build sandbox is
  conf-local: --disable-nls --without-selinux --without-posix-acls

environment:
  FORCE_UNSAFE_CONFIGURE: '1'

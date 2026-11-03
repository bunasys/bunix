kind: autotools
description: GNU cpio -- packs the root file system into the kernel's initramfs format

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:cpio/cpio-2.15.tar.bz2
  ref: 937610b97c329a1ec9268553fb780037bcfff0dcffe9725ebc4fd9c1aa9075db

variables:
  conf-local: --disable-nls

environment:
  # cpio 2.15 declares functions with empty parameter lists, which C23
  # (gcc's default) reads as "no arguments"
  CFLAGS: "%{cflags} -std=gnu17"

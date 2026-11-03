kind: autotools
description: dosfstools -- mkfs.fat makes the EFI system partitions of the ISO and the disk image

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz
  ref: 64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527

variables:
  # mkfs.vfat: the name systemd-repart runs (system/disk.bst).  No iconv:
  # the system has no gconv modules; the built-in CP850 table is enough
  conf-local: --enable-compat-symlinks --without-iconv

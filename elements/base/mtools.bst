kind: autotools
description: mtools -- mcopy, which systemd-repart uses to fill FAT partitions (the ESPs of system/live.bst and system/disk.bst)

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:mtools/mtools-4.0.50.tar.bz2
  ref: f3a58e6cfc2634b03c240442548e3b00103692357afc28e1e7104744dd6478b5

variables:
  conf-local: --without-x

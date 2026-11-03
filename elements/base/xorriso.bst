kind: autotools
description: |
  GNU xorriso -- writes the ISO image, bootable on BIOS and UEFI machines
  and as a raw USB disk.  The GNU release bundles libburn and libisofs.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:xorriso/xorriso-1.5.6.pl02.tar.gz
  ref: 786f9f5df9865cc5b0c1fecee3d2c0f5e04cab8c9a859bd1c9c7ccd4964fdae1

variables:
  conf-local: --disable-static

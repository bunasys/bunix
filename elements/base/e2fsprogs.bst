kind: autotools
description: |
  e2fsprogs -- mkfs.ext4 and e2fsck.  systemd-repart creates the installed
  system's ext4 root partition on first boot with it; e2fsck checks it.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/util-linux.bst

sources:
- kind: tar
  url: kernel:linux/kernel/people/tytso/e2fsprogs/v1.47.4/e2fsprogs-1.47.4.tar.xz
  ref: fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b

variables:
  # libuuid and libblkid come from util-linux; no FUSE, no translations
  conf-local: >-
    --disable-static --disable-nls --disable-libuuid --disable-libblkid
    --disable-uuidd --disable-fsck --disable-fuse2fs --disable-e2initrd-helper
    --enable-elf-shlibs --with-crond-dir=no --with-systemd-unit-dir=no
    --with-udev-rules-dir=no

config:
  install-commands:
    (>):
    # the libraries' headers and .so links
    - make DESTDIR=%{install-root} install-libs

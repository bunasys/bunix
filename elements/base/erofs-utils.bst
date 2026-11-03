kind: autotools
description: |
  erofs-utils -- mkfs.erofs, which systemd-repart runs to make the read-only
  file systems of system extension images (a build tool)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/autoconf.bst
- base/automake.bst
- base/libtool.bst

depends:
- base/lz4.bst
- base/xz.bst
- base/zlib.bst
- base/util-linux.bst

sources:
- kind: tar
  url: kernel-git:linux/kernel/git/xiang/erofs-utils.git/snapshot/erofs-utils-1.9.4.tar.gz
  ref: 7d135aa2550326a5acf20f53c518aea5a8900015ce50700044e40f818c31dd80

variables:
  # A git snapshot, without configure: the autotools element runs
  # autoreconf when there is none.  LZ4 (fast to read: the installed
  # system's /usr) and LZMA (small: extensions to download); zstd is still
  # marked experimental in mkfs.erofs.  FUSE mounting, S3/OCI import and
  # SELinux labels are off.
  conf-local: >-
    --enable-lz4 --enable-lzma --without-libzstd --disable-fuse
    --without-selinux --without-libcurl --without-openssl --without-libxml2
    --without-json_c --without-libnl3

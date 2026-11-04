kind: autotools
description: |
  libarchive -- bsdtar, which reads and writes zip, 7-Zip, ISO 9660 and
  the tar and cpio formats, and bsdunzip, installed as unzip.  A zip is
  made with `bsdtar -a -cf name.zip files...`.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/bzip2.bst
- base/lz4.bst
- base/openssl.bst
- base/xz.bst
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: https://www.libarchive.org/downloads/libarchive-3.8.10.tar.xz
  ref: 56cad765459d5ee25a3b761f90c47d99379d28297fbfb72d908880d6b875fb96

variables:
  # no XML (the xar format), no ACLs (no libacl)
  conf-local: >-
    --disable-static --enable-bsdtar --enable-bsdcat --enable-bsdunzip
    --disable-bsdcpio --disable-acl --without-xml2 --without-expat
    --without-libb2 --without-lzo2 --without-mbedtls --without-nettle

config:
  install-commands:
    (>):
    - ln -s bsdunzip %{install-root}%{bindir}/unzip

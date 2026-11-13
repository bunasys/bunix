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
  url: https://www.libarchive.org/downloads/libarchive-3.8.11.tar.xz
  ref: a3dc0872b1b39da34dc18ef1b944f0f11ffd37425d70ae04be679279f1cf43d2

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

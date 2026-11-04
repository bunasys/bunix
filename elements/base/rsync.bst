kind: autotools
description: |
  rsync -- copies trees, locally and over ssh, sending only what changed

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/openssl.bst
- base/zstd.bst
- base/lz4.bst
- base/zlib.bst
- base/popt.bst

sources:
- kind: tar
  url: https://download.samba.org/pub/rsync/src/rsync-3.5.2.tar.gz
  ref: a10d591825251e070f74c98df3daad195def4ed81b4a2de16169026aea33f6c8

variables:
  # the system's zlib and popt, not rsync's bundled copies; xxHash and
  # libidn2 are not packaged (MD5 and the faster zstd/lz4 compression are)
  conf-local: >-
    --with-included-zlib=no --with-included-popt=no
    --disable-xxhash --disable-idn --disable-md2man --disable-debug

kind: autotools
description: |
  libcurl with versioned symbols (CURL_OPENSSL_4), as Debian and Ubuntu
  build it, for the Swift toolchain's FoundationNetworking.  bunix's own
  libcurl (base/curl.bst, same version) has no symbol versions, and the
  dynamic loader warns about every program that expects them.

build-depends:
- bootstrap/build-env.bst
- base/openssl.bst
- base/zlib.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: curl:download/curl-8.23.0.tar.xz
  ref: 8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5

variables:
  prefix: /usr/lib/swift-toolchain/deps
  libdir: "%{prefix}/lib"
  # as base/curl.bst, plus the versioned symbols; the library only
  conf-local: >-
    --enable-versioned-symbols --disable-static
    --with-openssl --with-zlib
    --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-path=/etc/ssl/certs
    --without-libpsl --without-nghttp2 --without-libidn2 --without-brotli
    --without-zstd --disable-manual --disable-docs

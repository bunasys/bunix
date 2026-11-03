kind: autotools
description: curl and libcurl, with OpenSSL for TLS and Mozilla's CA bundle

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/openssl.bst
- base/zlib.bst

runtime-depends:
- base/ca-certificates.bst

sources:
- kind: tar
  url: curl:download/curl-8.23.0.tar.xz
  ref: 8dadd7d2536a314f982ad05a651b713f426bf7d02cc2c76cffb9796f2218e6c5

variables:
  # libpsl (cookie domain rules) and the HTTP/2/3 libraries are optional,
  # and nothing else here needs them
  conf-local: >-
    --with-openssl --with-zlib
    --with-ca-bundle=/etc/ssl/certs/ca-certificates.crt --with-ca-path=/etc/ssl/certs
    --without-libpsl --without-nghttp2 --without-libidn2 --without-brotli
    --without-zstd --without-libssh2
    --disable-static --disable-manual --disable-docs --disable-ldap

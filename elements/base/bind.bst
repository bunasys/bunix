kind: autotools
description: |
  BIND's DNS client tools: dig, host, nslookup, delv, nsupdate.  The name
  server (named) and its zone tools are not built.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
- base/perl.bst

depends:
- base/openssl.bst
- base/libuv.bst
- base/userspace-rcu.bst
- base/libcap.bst
- base/readline.bst

sources:
- kind: tar
  url: isc:bind9/9.20.30/bind-9.20.30.tar.xz
  ref: 9e1443a40a72a30272cbc3196d020a6b2e26937111c83e59e101e82e1e3b4fef

variables:
  # DNS-over-HTTPS (nghttp2), GeoIP, dnstap, LMDB, GSSAPI, IDN, the
  # statistics channel's XML/JSON and jemalloc are optional and all off
  conf-local: >-
    --disable-static --disable-doh --disable-geoip --disable-dnstap
    --without-lmdb --without-gssapi --without-libidn2 --without-libxml2
    --without-json-c --without-zlib --without-jemalloc --without-maxminddb
    --without-cmocka --with-readline

config:
  # Only the libraries and the client tools: the rest (named, tests, and the
  # docs, which run freshly built programs) is not wanted.  bin/dig also
  # builds host and nslookup.
  build-commands:
  # delv embeds the DNSSEC root key, generated at the top level (by perl)
  - make bind.keys.h
  - make -C lib
  - for tool in dig delv nsupdate; do make -C bin/$tool; done
  install-commands:
  - make -C lib DESTDIR=%{install-root} install
  - for tool in dig delv nsupdate; do make -C bin/$tool DESTDIR=%{install-root} install; done
  - find %{install-root} -name '*.la' -delete

kind: manual
description: OpenSSL -- TLS for curl, cargo and BIND; DNSSEC and DNS-over-TLS for resolved

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/perl.bst

sources:
- kind: tar
  url: github:openssl/openssl/releases/download/openssl-3.5.9/openssl-3.5.9.tar.gz
  ref: 603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a

config:
  configure-commands:
  # --libdir is relative to the prefix; Configure takes the flags from the
  # environment
  - |
    ./Configure linux-x86_64 --prefix=%{prefix} --libdir=%{lib} \
      --openssldir=/etc/ssl shared no-static-engine no-tests no-docs
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install_sw install_ssldirs
  - rm %{install-root}%{libdir}/libssl.a %{install-root}%{libdir}/libcrypto.a

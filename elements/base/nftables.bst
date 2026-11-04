kind: autotools
description: |
  nftables -- nft, which loads bunix's firewall (files/rootfs:
  /usr/lib/bunix/firewall.nft, nftables.service).  Without its interactive
  shell, JSON output and the iptables compatibility layer; with its
  bundled mini-GMP instead of GMP.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libmnl.bst
- base/libnftnl.bst

sources:
- kind: tar
  url: netfilter:nftables/files/nftables-1.1.7.tar.xz
  ref: a6fbf060d8d4fff001517a2b94f356bb4366bfbf0ba366366f9d27cc38caa58f

variables:
  conf-local: >-
    --disable-static --disable-man-doc --disable-debug
    --with-mini-gmp --without-cli --without-json --without-xtables

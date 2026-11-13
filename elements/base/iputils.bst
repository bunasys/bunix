kind: meson
description: |
  iputils -- ping, in place of BusyBox's.  BusyBox's ping opens only raw
  ICMP sockets, which need root; this one falls back to the ICMP datagram
  sockets the kernel gives every user (systemd's net.ipv4.ping_group_range),
  so it needs no setuid bit or capability.

build-depends:
- bootstrap/build-env.bst
- base/meson.bst
- base/ninja.bst
- base/pkgconf.bst

sources:
- kind: tar
  url: github:iputils/iputils/releases/download/20250605/iputils-20250605.tar.xz
  ref: 6f213700dbf96b5cc4499ca70cb15ecd69c09f405b06785bb4a1a10b572b6276

variables:
  # ping only: arping and clockdiff need raw sockets, so root, anyway.
  # libcap is for dropping capabilities ping would have been given, and
  # this ping is given none.
  meson-local: >-
    -DBUILD_PING=true -DBUILD_ARPING=false -DBUILD_CLOCKDIFF=false
    -DBUILD_TRACEPATH=false -DBUILD_MANS=false
    -DUSE_CAP=false -DUSE_IDN=false -DUSE_GETTEXT=false

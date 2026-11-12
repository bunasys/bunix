kind: make
description: |
  wireguard-tools -- wg, which shows and sets WireGuard interfaces' keys and
  peers.  systemd-networkd sets the interfaces up (Kind=wireguard), so no
  wg-quick and no units of its own.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://git.zx2c4.com/wireguard-tools/snapshot/wireguard-tools-1.0.20260223.tar.xz
  ref: af459827b80bfd31b83b08077f4b5843acb7d18ad9a33a2ef532d3090f291fbf

variables:
  command-subdir: src
  make-args: >-
    PREFIX=%{prefix} BINDIR=%{bindir}
    WITH_WGQUICK=no WITH_SYSTEMDUNITS=no WITH_BASHCOMPLETION=no

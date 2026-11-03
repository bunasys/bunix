kind: manual
description: |
  The wireless regulatory database -- which channels and transmit powers are
  legal where.  cfg80211 loads it like firmware and checks its signature
  against keys built into the kernel.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: kernel:software/network/wireless-regdb/wireless-regdb-2026.09.03.tar.xz
  ref: b22e0901227b820cd1c280abe681a15b773a5103a5e10dc442e94ebb34cbf58d

config:
  install-commands:
  - install -D -m 0644 regulatory.db %{install-root}/usr/lib/firmware/regulatory.db
  - install -D -m 0644 regulatory.db.p7s %{install-root}/usr/lib/firmware/regulatory.db.p7s

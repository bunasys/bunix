kind: manual
description: |
  Nawa -- Buna Systems' agent harness (github.com/bunasys/nawa): nawa repl,
  acp, serve, config.

  A binary seed, like bootstrap/rust-seed.bst and system/shim.bst: Nawa's own
  static Linux release, pinned by checksum.  Building it here would need a
  Swift toolchain, which bunix does not bootstrap yet.  The release is
  statically linked (Swift's Static Linux SDK, musl), so it needs none of
  bunix's libraries; HTTPS uses the CA bundle in /etc/ssl/certs.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:bunasys/nawa/releases/download/v0.8.0/nawa-0.8.0-linux-amd64.tar.gz
  ref: 0460c75597a5fcdbde652a318d96e99b43abc58ed838036a11037d06e661c886
  # the archive has nawa, README.md and LICENSE at its top level
  base-dir: ""

config:
  install-commands:
  - install -D -m 0755 nawa %{install-root}%{bindir}/nawa
  - install -D -m 0644 LICENSE %{install-root}/usr/share/licenses/nawa/LICENSE

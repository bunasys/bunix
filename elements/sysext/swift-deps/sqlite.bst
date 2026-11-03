kind: autotools
description: |
  SQLite -- for the Swift toolchain's package manager, driver and
  sourcekit-lsp (libsqlite3.so.0).  The system has no SQLite of its own.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: sqlite:2026/sqlite-autoconf-3540100.tar.gz
  ref: 926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e

variables:
  prefix: /usr/lib/swift-toolchain/deps
  libdir: "%{prefix}/lib"
  conf-local: --disable-static --disable-readline

kind: autotools
description: |
  SQLite -- the database Sequoia's certificate store keeps, linked by sqop
  (tools/sqop.bst).  Not part of the system.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: sqlite:2026/sqlite-autoconf-3540100.tar.gz
  ref: 926ef8d3eab93fbf6e06011901273eec076b25594a4e1cdadd50c987f4f6d64e

variables:
  conf-local: --disable-static --disable-readline

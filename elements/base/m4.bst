kind: autotools
description: GNU m4 -- the macro processor autoconf is written in

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:m4/m4-1.4.21.tar.xz
  ref: f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66

variables:
  conf-local: --disable-nls

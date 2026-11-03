kind: autotools
description: Expat -- the XML parser dbus-daemon reads its policy files with

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:libexpat/libexpat/releases/download/R_2_9_0/expat-2.9.0.tar.xz
  ref: 1e6371862cc31999b368c3b89b49994f0677e1bab5f1b2b85ae3741f5d803051

variables:
  conf-local: --disable-static --without-docbook --without-examples --without-tests

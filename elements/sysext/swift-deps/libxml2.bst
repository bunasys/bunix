kind: autotools
description: |
  libxml2 2.13 -- for the Swift toolchain's Foundation, lldb and lld.  The
  2.13 series is the last named libxml2.so.2, the name they ask for (2.14
  became libxml2.so.16).

build-depends:
- bootstrap/build-env.bst
- base/zlib.bst

sources:
- kind: tar
  url: gnome:libxml2/2.13/libxml2-2.13.9.tar.xz
  ref: a2c9ae7b770da34860050c309f903221c67830c86e4a7e760692b803df95143a

variables:
  prefix: /usr/lib/swift-toolchain/deps
  libdir: "%{prefix}/lib"
  conf-local: --disable-static --without-python --without-lzma --without-icu --without-readline

kind: autotools
description: |
  libedit -- line editing, for the Swift toolchain's lldb.  Debian names the
  library libedit.so.2 where upstream says libedit.so.0; lldb asks for the
  former, which is added as a link.

build-depends:
- bootstrap/build-env.bst
- sysext/swift-deps/ncurses.bst

sources:
- kind: tar
  url: thrysoee:editline/libedit-20251016-3.1.tar.gz
  ref: 21362b00653bbfc1c71f71a7578da66b5b5203559d43134d2dd7719e313ce041

variables:
  prefix: /usr/lib/swift-toolchain/deps
  libdir: "%{prefix}/lib"
  conf-local: --disable-static --disable-examples

environment:
  # the toolchain's ncurses (libtinfo), not the system's
  CPPFLAGS: -I/usr/lib/swift-toolchain/deps/include
  LDFLAGS: -L/usr/lib/swift-toolchain/deps/lib

config:
  install-commands:
    (>):
    - ln -s libedit.so.0 %{install-root}%{libdir}/libedit.so.2

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
  url: thrysoee:editline/libedit-20260512-3.1.tar.gz
  ref: 432d5e7ea8b0116dd39f2eca7bc11d0eed77faa6b77ea526ace89907c23ea4a0

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

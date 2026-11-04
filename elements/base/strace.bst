kind: autotools
description: strace -- traces a program's system calls and signals

build-depends:
- bootstrap/build-env.bst

depends:
# colours the output when it is a terminal (terminfo).  Declared so it
# links bunix's ncurses, not the build environment's temporary one.
- base/ncurses.bst

sources:
- kind: tar
  url: github:strace/strace/releases/download/v7.3/strace-7.3.tar.xz
  ref: 529634c40910895a9a1f3c5c1e65da2ca9ed72fb158dfc4bcc89efdf05e39b72

variables:
  # mpers: decoding 32-bit programs' structures, for a 32-bit userland
  # this system does not have
  conf-local: --enable-mpers=no --disable-gcc-Werror --without-libdw --without-libunwind

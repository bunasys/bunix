kind: autotools
description: |
  GDB, the GNU debugger, and gdbserver.  With its text interface (gdb
  -tui) and compressed debug sections (zlib, zstd, xz); without Python
  and Guile scripting and debuginfod.

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/expat.bst
- base/gmp.bst
- base/mpfr.bst
- base/ncurses.bst
- base/readline.bst
- base/xz.bst
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: gnu:gdb/gdb-18.1.tar.xz
  ref: cd9fc3fe2b47743840e42c1592d3d87f8302eb18639c0b8b4ba0898002e2348f

variables:
  conf-local: >-
    --disable-nls --disable-werror --disable-sim --disable-gprofng
    --with-system-readline --with-system-zlib --with-zstd --with-lzma --with-expat
    --enable-tui --without-python --without-guile --without-debuginfod
    --without-babeltrace --without-xxhash --without-intel-pt

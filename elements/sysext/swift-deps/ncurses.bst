kind: autotools
description: |
  ncurses as Debian and Ubuntu build it, for the Swift toolchain only: the
  narrow-character libncurses.so.6 with the terminfo functions split out
  into libtinfo.so.6, and versioned symbols (NCURSES6_TINFO_5.0.19991023,
  ...).  swift-driver, swift-package and lldb were built against those.
  bunix's own ncurses (base/ncurses.bst) is the wide-character build under
  the same file name, so this one lives in the toolchain's private
  directory (sysext/swift-tree.bst).

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:ncurses/ncurses-6.6.tar.gz
  ref: 355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11

variables:
  prefix: /usr/lib/swift-toolchain/deps
  libdir: "%{prefix}/lib"
  # the system's terminal descriptions; none are installed here
  conf-local: >-
    --with-shared --without-normal --without-debug
    --disable-widec --with-termlib --with-versioned-syms --with-abi-version=6
    --without-cxx --without-cxx-binding --without-ada --without-progs
    --without-manpages --without-tests --disable-db-install --disable-stripping
    --with-terminfo-dirs=/etc/terminfo:/usr/share/terminfo
    --with-default-terminfo-dir=/usr/share/terminfo

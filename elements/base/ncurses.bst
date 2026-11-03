kind: autotools
description: ncurses -- terminal handling library, and the terminfo database

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: gnu:ncurses/ncurses-6.6.tar.gz
  ref: 355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11

variables:
  # One library, as on Arch: libncurses.so.6 holds the terminfo functions too.
  # (Split out with --with-termlib, programs that use curses but link only
  # -lncurses miss stdscr, which then lives in libtinfo.)  It is the wide-
  # character build; --disable-lib-suffixes names it plain libncurses.
  conf-local: >-
    --with-shared --without-normal --without-debug
    --enable-widec --disable-lib-suffixes --enable-overwrite
    --enable-pc-files --with-pkg-config-libdir=%{libdir}/pkgconfig
    --without-cxx --without-cxx-binding --without-ada --without-manpages
    --without-tests --disable-stripping

config:
  install-commands:
    (>):
    # Other names programs ask for: -ltinfo (bash, readline) and -lncursesw
    # (htop).  Binaries record the real soname either way: libncurses.so.6.
    - |
      cd %{install-root}%{libdir}
      echo 'INPUT(-lncurses)' > libtinfo.so
      ln -s ncurses.pc pkgconfig/tinfo.pc
      for lib in ncurses panel menu form; do
        ln -s lib$lib.so lib${lib}w.so
        ln -s $lib.pc pkgconfig/${lib}w.pc
      done
      ln -s . %{install-root}%{includedir}/ncursesw

public:
  bst:
    # replaces the bootstrap's temporary ncurses in build sandboxes
    overlap-whitelist:
    - "**"

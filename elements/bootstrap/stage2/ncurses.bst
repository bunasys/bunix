kind: manual
description: ncurses (bootstrap stage 2 temporary tool) -- bash needs a terminal library

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:ncurses/ncurses-6.6.tar.gz
  ref: 355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11

config:
  configure-commands:
  # installing compiles the terminfo database, which needs a tic that runs here
  - mkdir build-tic
  - cd build-tic && ../configure AWK=gawk && make -C include && make -C progs tic
  - |
    ./configure --prefix=/usr --libdir=/usr/lib/%{triplet} \
      --host=%{cross-triplet} --build=%{seed-triplet} \
      --with-shared --without-normal --with-cxx-shared --without-debug \
      --without-ada --without-manpages --disable-stripping AWK=gawk
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} TIC_PATH=$(pwd)/build-tic/progs/tic install
  # programs that ask for -lncurses get the wide-character library
  - ln -s libncursesw.so %{install-root}%{sysroot}/usr/lib/%{triplet}/libncurses.so
  - sed -e 's/^#if.*XOPEN.*$/#if 1/' -i %{install-root}%{sysroot}/usr/include/curses.h

kind: autotools
description: GNU readline -- line editing (iwctl, nsupdate, fdisk)

build-depends:
- bootstrap/build-env.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: gnu:readline/readline-8.3.tar.gz
  ref: fe5383204467828cd495ee8d1d3c037a7eba1389c22bc6a041f627976f9061cc

variables:
  conf-local: --with-curses --disable-static --disable-install-examples
  # readline leaves linking a terminal library to the program unless told
  make-args: SHLIB_LIBS=-ltinfo

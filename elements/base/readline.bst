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
# GNU's official fixes for 8.3 (ftp.gnu.org/gnu/readline/readline-8.3-patches).
# 002 is the one bunix needed: interactive iwctl crashed at its first prompt
# (rl_prompt set to NULL).
- kind: patch
  path: files/readline/readline83-001
  strip-level: 0
- kind: patch
  path: files/readline/readline83-002
  strip-level: 0
- kind: patch
  path: files/readline/readline83-003
  strip-level: 0
- kind: patch
  path: files/readline/readline83-004
  strip-level: 0
- kind: patch
  path: files/readline/readline83-005
  strip-level: 0
- kind: patch
  path: files/readline/readline83-006
  strip-level: 0

variables:
  conf-local: --with-curses --disable-static --disable-install-examples
  # readline leaves linking a terminal library to the program unless told
  make-args: SHLIB_LIBS=-ltinfo

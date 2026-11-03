kind: autotools
description: psmisc -- killall, pstree, fuser, peekfd, prtstat

build-depends:
- bootstrap/build-env.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: sourceforge:psmisc/psmisc/psmisc-23.7.tar.xz
  ref: 58c55d9c1402474065adae669511c191de374b0871eec781239ab400b907c327

variables:
  conf-local: --disable-nls

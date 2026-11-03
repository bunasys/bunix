kind: autotools
description: htop -- the interactive process viewer

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/ncurses.bst

sources:
- kind: tar
  url: github:htop-dev/htop/releases/download/3.5.3/htop-3.5.3.tar.xz
  ref: a8b164386494cb85bb255a415a3f5f80afe7a0c4491da5d113b3a0f951087e65

variables:
  # sensors (lm-sensors), delay accounting (libnl) and hwloc are optional
  # libraries this system does not have
  conf-local: --enable-unicode --disable-sensors --disable-delayacct --disable-hwloc

kind: manual
description: bash (bootstrap stage 2 temporary tool) -- the shell of stage 3

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst
- bootstrap/stage2/ncurses.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:bash/bash-5.3.tar.gz
  ref: 0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet} --without-bash-malloc
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - ln -s bash %{install-root}%{sysroot}/usr/bin/sh

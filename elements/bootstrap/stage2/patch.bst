kind: manual
description: GNU patch (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:patch/patch-2.8.1.tar.xz
  ref: 3240c7959c5347c8ed347e3c4201c0337bf4240d5cf09d68889e58eeaba30e17

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

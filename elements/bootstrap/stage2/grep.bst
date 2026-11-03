kind: manual
description: GNU grep (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:grep/grep-3.12.tar.xz
  ref: 2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

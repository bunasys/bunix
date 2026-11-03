kind: manual
description: GNU tar (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin
  FORCE_UNSAFE_CONFIGURE: "1"

sources:
- kind: tar
  url: gnu:tar/tar-1.35.tar.xz
  ref: 4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

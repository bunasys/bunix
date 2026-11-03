kind: manual
description: GNU make (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:make/make-4.4.1.tar.gz
  ref: dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet} --without-guile
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

kind: manual
description: GNU findutils (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:findutils/findutils-4.11.0.tar.xz
  ref: bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet} --localstatedir=/var/lib/locate
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

kind: manual
description: GNU sed (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:sed/sed-4.10.tar.xz
  ref: b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

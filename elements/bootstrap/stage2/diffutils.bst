kind: manual
description: GNU diffutils (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:diffutils/diffutils-3.12.tar.xz
  ref: 7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet} gl_cv_func_strcasecmp_works=y
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

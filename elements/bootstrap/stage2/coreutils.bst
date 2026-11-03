kind: manual
description: GNU coreutils (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin
  FORCE_UNSAFE_CONFIGURE: "1"

sources:
- kind: tar
  url: gnu:coreutils/coreutils-9.12.tar.xz
  ref: a480198559733e9b3da999e90543ac6f888a2caa544d8d664c5a1f17e528e210

config:
  configure-commands:
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet} --enable-install-program=hostname --enable-no-install-program=kill,uptime
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

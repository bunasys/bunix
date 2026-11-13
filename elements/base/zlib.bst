kind: manual
description: zlib -- the deflate compression library

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:madler/zlib/releases/download/v1.4/zlib-1.4.tar.xz
  ref: 4f11c512053d7bab8d9e9b89bde3575add3e4c50a383b42ef6cb837035fc5a7c

config:
  configure-commands:
  # zlib's configure is hand-written and rejects the usual autoconf options
  - ./configure --prefix=%{prefix} --libdir=%{libdir}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install
  - rm %{install-root}%{libdir}/libz.a

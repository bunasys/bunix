kind: manual
description: zlib -- the deflate compression library

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.xz
  ref: d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3

config:
  configure-commands:
  # zlib's configure is hand-written and rejects the usual autoconf options
  - ./configure --prefix=%{prefix} --libdir=%{libdir}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install
  - rm %{install-root}%{libdir}/libz.a

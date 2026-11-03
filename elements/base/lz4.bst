kind: manual
description: |
  LZ4 -- fast compression; mkfs.erofs compresses the installed system's /usr
  with it, which decompresses several times faster than LZMA on every read

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:lz4/lz4/releases/download/v1.10.0/lz4-1.10.0.tar.gz
  ref: 537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b

config:
  build-commands:
  - make
  install-commands:
  - make PREFIX=%{prefix} LIBDIR=%{libdir} DESTDIR=%{install-root} install
  - rm %{install-root}%{libdir}/liblz4.a

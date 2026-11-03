kind: manual
description: zstd -- compresses the initramfs, which holds the whole root file system

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:facebook/zstd/releases/download/v1.5.7/zstd-1.5.7.tar.gz
  ref: eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3

config:
  build-commands:
  - make
  install-commands:
  - make PREFIX=%{prefix} LIBDIR=%{libdir} DESTDIR=%{install-root} install
  - rm %{install-root}%{libdir}/libzstd.a

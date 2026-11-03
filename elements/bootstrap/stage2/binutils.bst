kind: manual
description: |
  binutils, pass 2 (bootstrap stage 2): cross-compiled to run on the target,
  so stage 3 has a linker and assembler.  Static: temporary, and it keeps
  libtool from linking against anything outside the sysroot.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:binutils/binutils-2.47.tar.xz
  ref: 154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff

config:
  configure-commands:
  - mkdir build
  - |
    cd build && ../configure \
      --prefix=/usr --build=%{seed-triplet} --host=%{cross-triplet} \
      --with-lib-path=/usr/lib/%{triplet}:/usr/lib \
      --disable-nls --disable-shared --enable-gprofng=no --disable-werror \
      --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root}%{sysroot} install

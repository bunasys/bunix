kind: manual
description: Cross binutils for x86_64-bunix-linux-gnu (bootstrap stage 1)

build-depends:
- bootstrap/seed.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:binutils/binutils-2.47.tar.xz
  ref: 154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff

config:
  configure-commands:
  - mkdir build
  # --with-lib-path: the linker's default search path inside the sysroot
  # ('=' means "relative to the sysroot"), multiarch $libdir first
  - |
    cd build && ../configure \
      --prefix=%{tools} --target=%{cross-triplet} --with-sysroot=%{sysroot} \
      --with-lib-path==/usr/lib/%{triplet}:=/usr/lib \
      --disable-nls --enable-gprofng=no --disable-werror \
      --enable-new-dtags --enable-default-hash-style=gnu
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root} install

kind: manual
description: binutils, built natively -- the final assembler and linker (bootstrap stage 3)

build-depends:
- bootstrap/stage3/root.bst
- bootstrap/stage3/glibc.bst

sources:
- kind: tar
  url: gnu:binutils/binutils-2.47.tar.xz
  ref: 154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff

config:
  configure-commands:
  - mkdir build
  - |
    cd build && ../configure \
      --build=%{triplet} --host=%{triplet} --target=%{triplet} \
      --prefix=/usr --libdir=%{libdir} --sysconfdir=/etc \
      --with-lib-path=%{libdir}:/usr/lib \
      --enable-ld=default --enable-plugins --enable-shared --disable-static \
      --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu \
      --enable-gprofng=no --disable-nls --disable-werror
  build-commands:
  - make -C build tooldir=/usr
  install-commands:
  - make -C build DESTDIR=%{install-root} tooldir=/usr install
  - rm -f %{install-root}%{libdir}/*.la

public:
  bst:
    # replaces the stage-3 root's temporary files
    overlap-whitelist:
    - "**"

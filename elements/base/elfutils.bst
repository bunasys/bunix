kind: manual
description: |
  libelf from elfutils -- objtool, which checks and annotates the kernel's
  object code, reads ELF files with it.  Only the library is built.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/zlib.bst

sources:
- kind: tar
  url: sourceware:elfutils/0.196/elfutils-0.196.tar.bz2
  ref: fd5cc6b77ad6773cac93cb3f415f9318ac3b3455eecf801f6b4a742c4f6c7209

config:
  configure-commands:
  - |
    ./configure --prefix=%{prefix} --libdir=%{libdir} --disable-nls \
      --disable-debuginfod --enable-libdebuginfod=dummy \
      --without-bzlib --without-lzma --without-zstd
  build-commands:
  - make -C lib
  - make -C libelf
  install-commands:
  - make -C libelf DESTDIR=%{install-root} install
  - install -D -m 0644 config/libelf.pc %{install-root}%{libdir}/pkgconfig/libelf.pc
  - rm %{install-root}%{libdir}/libelf.a

kind: manual
description: |
  libelf and libdw from elfutils -- objtool, which checks and annotates the
  kernel's object code, reads ELF files with libelf; pahole
  (base/dwarves.bst) reads the kernel's DWARF with libdw to make its BTF.
  Only the libraries are built, not elfutils' programs.

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
  # libdw is linked from these parts' static archives
  - |
    for part in libcpu backends libebl libdwelf libdwfl libdwfl_stacktrace libdw; do
      make -C $part
    done
  install-commands:
  - make -C libelf DESTDIR=%{install-root} install
  - install -D -m 0644 config/libelf.pc %{install-root}%{libdir}/pkgconfig/libelf.pc
  - |
    for part in libdw libdwfl libdwelf; do
      make -C $part DESTDIR=%{install-root} install
    done
  # (the top-level Makefile installs this one, and it would build the programs)
  - install -m 0644 version.h %{install-root}%{includedir}/elfutils/version.h
  - install -m 0644 config/libdw.pc %{install-root}%{libdir}/pkgconfig/libdw.pc
  - rm -f %{install-root}%{libdir}/libelf.a %{install-root}%{libdir}/libdw.a

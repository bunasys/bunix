kind: manual
description: |
  libstdc++ for the target, built with the pass-1 cross compiler now that
  glibc exists (bootstrap stage 1).  The library goes into the sysroot; its
  headers go where the cross g++ looks for them, under /tools.

  libstdc++ appends the compiler's multilib OS directory
  (../lib/x86_64-linux-gnu) to --libdir, so --libdir is plain /usr/lib and
  the library still lands in the multiarch $libdir.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1/binutils.bst
- bootstrap/stage1/gcc.bst
- bootstrap/stage1/glibc.bst
- bootstrap/stage1/linux-headers.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:gcc/gcc-16.2.0/gcc-16.2.0.tar.xz
  ref: e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e

config:
  configure-commands:
  - mkdir build
  - |
    cd build && ../libstdc++-v3/configure \
      --host=%{cross-triplet} --build=$(../config.guess) \
      --prefix=%{sysroot}/usr --libdir=%{sysroot}/usr/lib \
      --disable-multilib --disable-nls --disable-libstdcxx-pch \
      --with-gxx-include-dir=%{tools}/%{cross-triplet}/include/c++/%{gcc-version}
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root} install
  - find %{install-root} -name '*.la' -delete

kind: manual
description: |
  gcc, pass 2 (bootstrap stage 2): cross-compiled to run on the target, so
  stage 3 has a native C/C++ compiler.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:gcc/gcc-16.2.0/gcc-16.2.0.tar.xz
  ref: e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e
- kind: tar
  url: gnu:gmp/gmp-6.3.0.tar.xz
  directory: gmp
  ref: a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
- kind: tar
  url: gnu:mpfr/mpfr-4.2.2.tar.xz
  directory: mpfr
  ref: b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01
- kind: tar
  url: gnu:mpc/mpc-1.4.1.tar.xz
  directory: mpc
  ref: 91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931

config:
  configure-commands:
  - sed -e '/m64=/s@\.\./lib64@../lib/%{triplet}@' -i gcc/config/i386/t-linux64
  # glibc now exists, so libgcc and libstdc++ can use POSIX threads
  - sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
  - mkdir build
  - |
    cd build && ../configure \
      --build=%{seed-triplet} --host=%{cross-triplet} --target=%{cross-triplet} \
      LDFLAGS_FOR_TARGET=-L$PWD/%{cross-triplet}/libgcc \
      --prefix=/usr --with-build-sysroot=%{sysroot} \
      --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib \
      --disable-libatomic --disable-libgomp --disable-libquadmath \
      --disable-libsanitizer --disable-libssp --disable-libvtv \
      --enable-languages=c,c++
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root}%{sysroot} install
  - ln -s gcc %{install-root}%{sysroot}/usr/bin/cc

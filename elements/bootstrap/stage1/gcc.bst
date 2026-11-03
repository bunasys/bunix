kind: manual
description: |
  Cross gcc, pass 1 (bootstrap stage 1): just enough C/C++ compiler to build
  glibc -- no libc headers yet, so no shared libgcc, threads or libstdc++.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1/binutils.bst

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
  # 64-bit libraries go in the multiarch $libdir, not lib64
  - sed -e '/m64=/s@\.\./lib64@../lib/%{triplet}@' -i gcc/config/i386/t-linux64
  - mkdir build
  - |
    cd build && ../configure \
      --target=%{cross-triplet} --prefix=%{tools} --with-sysroot=%{sysroot} \
      --with-glibc-version=%{glibc-version} --with-newlib --without-headers \
      --enable-default-pie --enable-default-ssp --disable-nls \
      --disable-shared --disable-multilib --disable-threads \
      --disable-libatomic --disable-libgomp --disable-libquadmath \
      --disable-libssp --disable-libvtv --disable-libstdcxx \
      --enable-languages=c,c++
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root} install
  # Built --without-headers, gcc installed a limits.h for a system without a
  # libc; glibc needs the full one
  - |
    gcc_include=$(dirname $(%{install-root}%{tools}/bin/%{cross-triplet}-gcc -print-libgcc-file-name))/include
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > "$gcc_include/limits.h"

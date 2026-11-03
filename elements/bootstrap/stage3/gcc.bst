kind: manual
description: gcc, built natively -- the final C/C++ compiler (bootstrap stage 3)

build-depends:
- bootstrap/stage3/root.bst
- bootstrap/stage3/glibc.bst
- bootstrap/stage3/binutils.bst

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
  # runtime libraries (libgcc_s, libstdc++, ...) in the multiarch $libdir;
  # gcc's private files, and its internal programs (cc1, collect2 -- UAPI.9
  # has no /usr/libexec), stay in /usr/lib/gcc/
  - sed -e '/m64=/s@\.\./lib64@../lib/%{triplet}@' -i gcc/config/i386/t-linux64
  - mkdir build
  - |
    cd build && ../configure \
      --build=%{triplet} --host=%{triplet} --target=%{triplet} \
      --prefix=/usr --libexecdir=/usr/lib --enable-languages=c,c++ \
      --enable-default-pie --enable-default-ssp --enable-host-pie \
      --enable-multiarch --disable-multilib --disable-bootstrap \
      --disable-fixincludes --disable-nls
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root} install
  - ln -s gcc %{install-root}/usr/bin/cc
  - find %{install-root} -name '*.la' -delete

public:
  bst:
    # replaces the stage-3 root's temporary files
    overlap-whitelist:
    - "**"

kind: manual
description: |
  GNU awk (bootstrap stage 2 temporary tool).

  5.3.2, not 5.4.1: gawk 5.4.1 built without MPFR turns an uninitialised
  array element into "0" once it has been compared, which garbles gcc's
  generated options.cc ("#error 0Wabsolute-value does not have a Var() flag").
  With MPFR it behaves; the final system's gawk is built with it.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:gawk/gawk-5.3.2.tar.xz
  ref: f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc

config:
  configure-commands:
  # the extras are not needed to build the toolchain
  - sed -i 's/extras//' Makefile.in
  - ./configure --prefix=/usr --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

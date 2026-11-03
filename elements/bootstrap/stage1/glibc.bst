kind: manual
description: glibc, cross-compiled into the sysroot (bootstrap stage 1)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1/python.bst
- bootstrap/stage1/binutils.bst
- bootstrap/stage1/gcc.bst
- bootstrap/stage1/linux-headers.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: gnu:glibc/glibc-2.44.tar.xz
  ref: 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667

config:
  configure-commands:
  - mkdir build
  # /usr/sbin is a symlink to /usr/bin on bunix (UAPI.9)
  - echo "rootsbindir=/usr/bin" > build/configparms
  # libraries, and the dynamic loader, in the multiarch $libdir
  - |
    cd build && ../configure \
      --prefix=/usr --libdir=/usr/lib/%{triplet} \
      --host=%{cross-triplet} --build=$(../scripts/config.guess) \
      --with-headers=%{sysroot}/usr/include --enable-kernel=%{glibc-min-kernel} \
      --disable-nscd --disable-werror \
      libc_cv_slibdir=/usr/lib/%{triplet}
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root}%{sysroot} install
  # x86_64 programs ask for /lib64/ld-linux-x86-64.so.2; UAPI.9 makes /lib64
  # a symlink to $libdir
  - ln -s usr/lib/%{triplet} %{install-root}%{sysroot}/lib64

kind: manual
description: glibc, built natively -- the final C library (bootstrap stage 3)

build-depends:
- bootstrap/stage3/root.bst
- bootstrap/stage3/bison.bst
- bootstrap/stage3/python.bst

sources:
- kind: tar
  url: gnu:glibc/glibc-2.44.tar.xz
  ref: 37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667

config:
  configure-commands:
  - mkdir build
  # UAPI.9: /usr/sbin is a symlink to /usr/bin, and there is no /usr/libexec.
  # glibc takes its install directories from configparms, not from configure.
  - |
    printf '%s\n' rootsbindir=/usr/bin sbindir=/usr/bin libexecdir=/usr/lib \
      > build/configparms
  - |
    cd build && ../configure \
      --prefix=/usr --libdir=%{libdir} libc_cv_slibdir=%{libdir} \
      --enable-kernel=%{glibc-min-kernel} --enable-stack-protector=strong \
      --disable-nscd --disable-werror
  build-commands:
  - make -C build
  install-commands:
  - make -C build DESTDIR=%{install-root} install
  - ln -s usr/lib/%{triplet} %{install-root}/lib64

public:
  bst:
    # replaces the stage-3 root's temporary files
    overlap-whitelist:
    - "**"

kind: manual
description: file and libmagic (bootstrap stage 2 temporary tool)

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst

environment:
  PATH: /tools/bin:/usr/bin

sources:
- kind: tar
  url: astron:file/file-5.48.tar.gz
  ref: ed14656883b23a364b4057c05595d93252da9bc473d30106519519d0da141283

config:
  configure-commands:
  # building the magic database runs `file`, so first a copy that runs here
  - mkdir build-host
  - cd build-host && ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib && make
  - ./configure --prefix=/usr --libdir=/usr/lib/%{triplet} --host=%{cross-triplet} --build=%{seed-triplet}
  build-commands:
  - make FILE_COMPILE=$(pwd)/build-host/src/file
  install-commands:
  - make DESTDIR=%{install-root}%{sysroot} install
  - rm -f %{install-root}%{sysroot}/usr/lib/%{triplet}/*.la

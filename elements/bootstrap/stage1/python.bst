kind: manual
description: |
  Python, as a build tool for stage 1: glibc's build scripts need it and the
  seed does not have it.  Native to the seed, installed in /tools.

build-depends:
- bootstrap/seed.bst

sources:
- kind: tar
  url: python:3.15.2/Python-3.15.2.tar.xz
  ref: 8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de

config:
  configure-commands:
  - ./configure --prefix=%{tools} --without-ensurepip --disable-test-modules
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

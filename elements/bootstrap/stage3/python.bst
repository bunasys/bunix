kind: manual
description: Python (bootstrap stage 3 temporary tool) -- glibc's build needs it

build-depends:
- bootstrap/stage3/root.bst

sources:
- kind: tar
  url: python:3.15.2/Python-3.15.2.tar.xz
  ref: 8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de

config:
  configure-commands:
  - ./configure --prefix=/usr --without-ensurepip --disable-test-modules
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

public:
  bst:
    # replaces the stage-3 root's temporary files
    overlap-whitelist:
    - "**"

kind: manual
description: GNU bison (bootstrap stage 3 temporary tool) -- glibc's build needs it

build-depends:
- bootstrap/stage3/root.bst

sources:
- kind: tar
  url: gnu:bison/bison-3.8.2.tar.xz
  ref: 9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2

config:
  configure-commands:
  - ./configure --prefix=/usr
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

public:
  bst:
    # replaces the stage-3 root's temporary files
    overlap-whitelist:
    - "**"

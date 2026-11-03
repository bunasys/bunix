kind: manual
description: |
  bc -- the calculator the kernel build computes its time constants with.
  Gavin Howard's implementation (as in Linux From Scratch): GNU bc needs ed
  and texinfo to build.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:gavinhoward/bc/releases/download/7.0.3/bc-7.0.3.tar.xz
  ref: 91eb74caed0ee6655b669711a4f350c25579778694df248e28363318e03c7fc4

config:
  configure-commands:
  # -G: skip the tests that need GNU bc to generate.  C99: in C23 (gcc's
  # default) true and false are keywords, which bc's token-pasting macros
  # turn into undeclared names.
  - CC='gcc -std=c99' ./configure --prefix=%{prefix} -G -O2
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

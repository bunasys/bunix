kind: autotools
description: GMP -- arbitrary-precision arithmetic (gdb evaluates expressions with it)

build-depends:
- bootstrap/build-env.bst
- base/m4.bst

sources:
- kind: tar
  url: gnu:gmp/gmp-6.3.0.tar.xz
  ref: a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898

variables:
  conf-local: --disable-static

environment:
  # configure's compiler test declares functions without prototypes, which
  # C23 -- gcc 16's default -- reads differently, and rejects every compiler
  CFLAGS: "%{cflags} -std=gnu17"

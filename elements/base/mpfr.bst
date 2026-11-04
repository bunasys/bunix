kind: autotools
description: MPFR -- floating point with exact rounding (gdb's floating-point expressions)

build-depends:
- bootstrap/build-env.bst

depends:
- base/gmp.bst

sources:
- kind: tar
  url: gnu:mpfr/mpfr-4.2.2.tar.xz
  ref: b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01

variables:
  conf-local: --disable-static

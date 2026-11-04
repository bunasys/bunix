kind: autotools
description: mtdev -- turns older touch screens' multitouch events into slots (libinput)

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://bitmath.org/code/mtdev/mtdev-1.1.7.tar.bz2
  ref: a107adad2101fecac54ac7f9f0e0a0dd155d954193da55c2340c97f2ff1d814e

variables:
  conf-local: --disable-static

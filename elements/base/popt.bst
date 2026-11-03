kind: autotools
description: popt -- command-line parsing; cryptsetup's configure requires it

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: rpm:popt/releases/popt-1.x/popt-1.19.tar.gz
  ref: c25a4838fc8e4c1c8aacb8bd620edb3084a3d63bf8987fdad3ca2758c63240f9

variables:
  conf-local: --disable-static --disable-nls

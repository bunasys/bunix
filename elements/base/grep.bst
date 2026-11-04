kind: autotools
description: |
  GNU grep, in place of BusyBox's: long lines, -P (PCRE2), and the options
  configure scripts and admins' scripts expect

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/pcre2.bst

sources:
- kind: tar
  url: gnu:grep/grep-3.12.tar.xz
  ref: 2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9

variables:
  conf-local: --disable-nls --enable-perl-regexp

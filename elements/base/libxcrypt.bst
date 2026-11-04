kind: autotools
description: |
  libxcrypt -- crypt(), which glibc no longer provides: password hashing
  (mokutil's MOK password)

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst
# generates the hash method tables
- base/perl.bst

sources:
- kind: tar
  url: github:besser82/libxcrypt/releases/download/v4.5.2/libxcrypt-4.5.2.tar.xz
  ref: 71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071

variables:
  # --disable-werror: glibc 2.44's strchr returns const for a const string,
  # which upstream's -Werror build does not expect yet (warnings only)
  conf-local: >-
    --disable-static --disable-werror --enable-hashes=strong,glibc
    --disable-obsolete-api --disable-failure-tokens

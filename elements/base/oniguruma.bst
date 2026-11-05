kind: autotools
description: |
  Oniguruma -- regular expressions; Ghostty finds links in the terminal's
  text with it

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:kkos/oniguruma/releases/download/v6.9.10/onig-6.9.10.tar.gz
  ref: 2a5cfc5ae259e4e97f86b68dfffc152cdaffe94e2060b770cb827238d769fc05

variables:
  conf-local: --disable-static

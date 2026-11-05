kind: autotools
description: |
  attr -- extended file attributes: libattr, whose headers libacl is built
  with (base/acl.bst stores its access lists as extended attributes), and
  getfattr/setfattr.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://download.savannah.nongnu.org/releases/attr/attr-2.6.0.tar.xz
  ref: 6c8a2148a7b85043b68492bce43316b0e2e214fc4e628c7ede078e76e216330b

variables:
  conf-local: --disable-static --disable-nls

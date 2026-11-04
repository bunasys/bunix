kind: autotools
description: |
  mokutil -- shim's Machine Owner Keys: lists the enrolled keys, asks shim
  to enroll a new one at the next boot, and reports whether Secure Boot
  is on

build-depends:
- bootstrap/build-env.bst
- base/autoconf.bst
- base/automake.bst
- base/pkgconf.bst

depends:
- base/efivar.bst
- base/keyutils.bst
- base/libxcrypt.bst
- base/openssl.bst

sources:
- kind: tar
  url: github:lcp/mokutil/archive/refs/tags/0.7.3.tar.gz
  ref: c741db1ffe48f59ce31ce49186886422957c57bef69b5b0e2c18a80406d946da

variables:
  # (its autogen.sh looks for autoreconf with `which`, which the build
  # environment does not have)
  autogen: autoreconf -ivf .
  conf-local: --with-bash-completion-dir=no

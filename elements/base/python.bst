kind: autotools
description: |
  Python 3 -- the build tools meson and Jinja2 run on.  Unlike the
  bootstrap's temporary Python it has zlib, OpenSSL, expat, bzip2 and libffi
  behind the standard library modules that need them (meson imports gzip;
  systemd-boot's elf2efi imports ctypes).

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/zlib.bst
- base/openssl.bst
- base/expat.bst
- base/bzip2.bst
- base/libffi.bst
- base/ncurses.bst
- base/readline.bst

sources:
- kind: tar
  url: python:3.15.2/Python-3.15.2.tar.xz
  ref: 8b5536d280142ecf6cdfe15d12a21ba1c65e300bbf7b28a8d0cdb849575797de

variables:
  # The same version as the bootstrap's, so modules installed for one
  # (meson, Jinja2) are where the other looks: /usr/lib/python3.15.
  conf-local: >-
    --enable-shared --with-system-expat --without-ensurepip
    --disable-test-modules

public:
  bst:
    # replaces the bootstrap's temporary Python in build sandboxes
    overlap-whitelist:
    - "**"

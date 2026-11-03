kind: manual
description: |
  Botan 3 -- the C++ cryptography library behind Sequoia (sqv, sqop).
  Sequoia's other production-ready backends, OpenSSL and Nettle, reach C
  through bindgen, which needs libclang; Botan's Rust bindings are written
  by hand.  Built as a static library only: it is linked into the programs
  and nothing of it is installed on the system.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/python.bst

sources:
- kind: tar
  url: botan:Botan-3.13.0.tar.xz
  ref: 12f5a8358890bbee82edfe9d2e7769b0a610b6dd0e0698aea13d20a675d84620

config:
  configure-commands:
  - |
    python3 configure.py --prefix=%{prefix} --libdir=%{lib} \
      --cc=gcc --os=linux --cpu=x86_64 \
      --disable-shared-library --without-documentation --no-install-python-module
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

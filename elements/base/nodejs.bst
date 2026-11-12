kind: manual
description: |
  Node.js -- only for building Hudhud (docs/browser.md): Chromium
  makes its built-in pages and DevTools with it.  Node 24: the major
  version Chromium is built with (it checks the version: base/
  chromium.bst).  Not on the running system.  Node's own copies of
  V8, ICU, OpenSSL and the rest; without npm and corepack.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/python.bst
- base/ninja.bst

sources:
- kind: tar
  url: https://nodejs.org/dist/v24.22.2/node-v24.22.2.tar.xz
  ref: 8fe2ec1723bb9f8d0b683907c82708debbeda64af21cb2aa214c4241eed0a061

config:
  configure-commands:
  # configure.py itself: the `configure` wrapper only accepts the Python
  # versions known when Node 24 came out, and the system has 3.15
  - python3 configure.py --prefix=%{prefix} --without-npm --without-corepack --ninja
  build-commands:
  # built on the Fly machine's 16 CPUs (tools/fly/README.md)
  - ninja -C out/Release -j16
  install-commands:
  - make install DESTDIR=%{install-root} BUILDTYPE=Release
  - '%{install-root}%{bindir}/node --version'

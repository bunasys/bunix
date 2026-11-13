kind: manual
description: |
  Node.js 24 with npm and corepack, in the devtools extension
  (sysext/devtools-content.bst), and what Hudhud is built with
  (docs/browser.md): Chromium makes its built-in pages and DevTools with
  it, and checks the major version (base/chromium.bst), so the version
  follows Chromium's.  Anyone who needs another Node fetches it
  themselves.  Node's own copies of V8, ICU, OpenSSL and the rest.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/python.bst
- base/ninja.bst

sources:
- kind: tar
  url: https://nodejs.org/dist/v24.22.3/node-v24.22.3.tar.xz
  ref: 48ca3aa8a9b02133356922ef4fc80200e00598c80a4ef446f7c39a459222593d

config:
  configure-commands:
  # configure.py itself: the `configure` wrapper only accepts the Python
  # versions known when Node 24 came out, and the system has 3.15
  - python3 configure.py --prefix=%{prefix} --ninja
  build-commands:
  # built on the Fly machine's 16 CPUs (tools/fly/README.md)
  - ninja -C out/Release -j16
  install-commands:
  - make install DESTDIR=%{install-root} BUILDTYPE=Release
  - '%{install-root}%{bindir}/node --version'
  # npm and corepack are scripts Node runs: their links must point into
  # the installed tree
  - test -e %{install-root}%{bindir}/npm && test -e %{install-root}%{bindir}/corepack

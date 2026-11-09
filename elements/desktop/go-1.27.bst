kind: manual
description: |
  Go 1.27 -- only for building DMS, the desktop shell (desktop/dms.bst,
  desktop/dms-greeter.bst), which needs 1.27.  Buna Browser keeps
  base/go.bst (1.26), so adding DMS does not rebuild Chromium; the two
  become one at the next Chromium update.  Compiled from source by the
  binary Go 1.25 of bootstrap/go-seed.bst.  Not on the running system.

  Installed as Go lays itself out, in /usr/lib/go-1.27 (beside 1.26's
  /usr/lib/go, should both ever be staged together).  Its go.env keeps it
  offline: it never fetches modules, nor a newer Go in its own place.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- bootstrap/go-seed.bst

sources:
- kind: tar
  url: golang:go1.27.3.src.tar.gz
  ref: 6e7749035cf360f06b2575d162ea79df9fda8ef671889e5c375f8e50777f26bb

environment:
  GOROOT_BOOTSTRAP: "%{tools}/go"
  # offline while Go builds itself, as its go.env is made below
  GOTOOLCHAIN: local
  GOPROXY: "off"

config:
  build-commands:
  - cd src && ./make.bash

  install-commands:
  - |
    goroot=%{install-root}%{prefix}/lib/go-1.27
    mkdir -p $goroot
    cp -a bin lib pkg src VERSION go.env $goroot/
  - |
    # Go's defaults for every build that uses this Go: never the network
    goenv=%{install-root}%{prefix}/lib/go-1.27/go.env
    sed -i -e 's/^GOPROXY=.*/GOPROXY=off/' -e 's/^GOTOOLCHAIN=.*/GOTOOLCHAIN=local/' $goenv
    cat $goenv
    grep -qx GOPROXY=off $goenv
    grep -qx GOTOOLCHAIN=local $goenv
  - '%{install-root}%{prefix}/lib/go-1.27/bin/go version'

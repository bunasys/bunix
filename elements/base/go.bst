kind: manual
description: |
  Go 1.26 -- only for building Hudhud (docs/browser.md): Dawn,
  Chromium's WebGPU, generates part of Tint's source (its shader
  compiler) with a Go program while Chromium builds.  It needs only Go's
  standard library.  Compiled from source by the binary Go 1.25 of
  bootstrap/go-seed.bst.  Not on the running system.

  Installed as Go lays itself out, in /usr/lib/go (the standard library's
  source is part of the toolchain), where Chromium's build links to it.
  Its go.env keeps it offline: it never fetches modules, nor a newer Go
  in its own place.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- bootstrap/go-seed.bst

sources:
- kind: tar
  url: golang:go1.26.11.src.tar.gz
  ref: d44101b0ff27ed2a4c75ad46c17b9c74359209e2eb2ca7c9df6cb4fdb68e1969

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
    goroot=%{install-root}%{prefix}/lib/go
    mkdir -p $goroot
    cp -a bin lib pkg src VERSION go.env $goroot/
  - |
    # Go's defaults for every build that uses this Go: never the network
    goenv=%{install-root}%{prefix}/lib/go/go.env
    sed -i -e 's/^GOPROXY=.*/GOPROXY=off/' -e 's/^GOTOOLCHAIN=.*/GOTOOLCHAIN=local/' $goenv
    cat $goenv
    grep -qx GOPROXY=off $goenv
    grep -qx GOTOOLCHAIN=local $goenv
  - '%{install-root}%{prefix}/lib/go/bin/go version'

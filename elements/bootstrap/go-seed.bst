kind: manual
description: |
  Binary Go 1.25.14 from go.dev: the compiler that compiles Go 1.26
  (base/go.bst), which only builds with an earlier Go.  Like rust-seed.bst
  it is a pinned binary that never reaches the final system; it is
  installed in /tools/go.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: golang:go1.25.14.linux-amd64.tar.gz
  ref: a21ae5633a269bcd7e90cf767e48225633795e99d831742cbf3397064fee7712

config:
  install-commands:
  - |
    mkdir -p %{install-root}%{tools}/go
    cp -a . %{install-root}%{tools}/go/

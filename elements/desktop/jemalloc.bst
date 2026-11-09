kind: autotools
description: |
  jemalloc -- a memory allocator, which Quickshell links (upstream's
  advice): QML's many small, short-lived objects fragment glibc's heap,
  and DMS runs for the whole session (desktop/quickshell.bst).

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:jemalloc/jemalloc/releases/download/5.4.0/jemalloc-5.4.0.tar.bz2
  ref: 200776fac271093e7c2f21edd6d62657ecd2be578d9328633f2a86bfa6ef4f1d

variables:
  conf-local: --disable-static

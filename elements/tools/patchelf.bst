kind: autotools
description: |
  patchelf -- edits ELF programs' library search paths.  sysext/swift-tree.bst
  points the Swift toolchain's programs at their private libraries with it.
  A build tool; not part of the system.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:NixOS/patchelf/releases/download/0.18.0/patchelf-0.18.0.tar.bz2
  ref: 1952b2a782ba576279c211ee942e341748fdb44997f704dd53def46cd055470b

kind: stack
description: |
  What the devtools extension is made from: tools for working on software
  and on a running system -- git, gdb, strace, file, libarchive's
  bsdtar and unzip, Firecracker for microVMs, and Node.js 24 with npm
  and corepack.
  sysext/devtools-tree.bst keeps only what the root file system does not
  have.

depends:
- base/git.bst
- base/gdb.bst
- base/strace.bst
- base/file.bst
- base/libarchive.bst
- base/firecracker.bst
- base/nodejs.bst

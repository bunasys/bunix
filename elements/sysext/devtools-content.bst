kind: stack
description: |
  What the devtools extension is made from: tools for working on software
  and on a running system -- git, gdb, strace, file, libarchive's
  bsdtar and unzip, and Firecracker for microVMs.
  sysext/devtools-tree.bst keeps only what the root file system does not
  have.

depends:
- base/git.bst
- base/gdb.bst
- base/strace.bst
- base/file.bst
- base/libarchive.bst
- base/firecracker.bst

kind: stack
description: |
  What the system's elements build in: the stage-3 root, the final toolchain,
  and stage 3's temporary Python and bison.  Elements outside bootstrap/ list
  this first in build-depends, so their own dependencies (base/ncurses, say)
  are staged over the stage-2 versions in the root.

depends:
- bootstrap/stage3/root.bst
- bootstrap/stage3/bison.bst
- bootstrap/stage3/python.bst
- bootstrap/toolchain.bst

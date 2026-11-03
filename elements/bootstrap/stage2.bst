kind: stack
description: Bootstrap stage 2 -- temporary tools, cross-compiled into the sysroot

depends:
- bootstrap/stage2/m4.bst
- bootstrap/stage2/ncurses.bst
- bootstrap/stage2/bash.bst
- bootstrap/stage2/coreutils.bst
- bootstrap/stage2/diffutils.bst
- bootstrap/stage2/file.bst
- bootstrap/stage2/findutils.bst
- bootstrap/stage2/gawk.bst
- bootstrap/stage2/grep.bst
- bootstrap/stage2/gzip.bst
- bootstrap/stage2/make.bst
- bootstrap/stage2/patch.bst
- bootstrap/stage2/sed.bst
- bootstrap/stage2/tar.bst
- bootstrap/stage2/xz.bst
- bootstrap/stage2/binutils.bst
- bootstrap/stage2/gcc.bst

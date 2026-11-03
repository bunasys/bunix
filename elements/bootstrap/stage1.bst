kind: stack
description: Bootstrap stage 1 -- the cross toolchain and the sysroot's libc

depends:
- bootstrap/stage1/binutils.bst
- bootstrap/stage1/gcc.bst
- bootstrap/stage1/linux-headers.bst
- bootstrap/stage1/glibc.bst
- bootstrap/stage1/libstdcxx.bst

kind: stack
description: The bootstrapped toolchain -- final glibc, binutils and gcc

depends:
- bootstrap/stage3/glibc.bst
- bootstrap/stage3/binutils.bst
- bootstrap/stage3/gcc.bst

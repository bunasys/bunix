kind: cmake
description: |
  dwarves -- pahole, which the kernel build uses to turn the kernel's
  DWARF debug information into BTF (/sys/kernel/btf/vmlinux), the type
  information BPF programs are compiled against.  Built with its own copy
  of libbpf.

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

depends:
- base/elfutils.bst
- base/zlib.bst

sources:
- kind: tar
  url: https://fedorapeople.org/~acme/dwarves/dwarves-1.32.tar.xz
  ref: 319cbf319e9fc92065a5407ce47eb868d73566f3d4840a56832734e4579df947

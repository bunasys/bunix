kind: manual
description: |
  libLLVM, the one part of base/llvm.bst the running system needs: Mesa
  (llvmpipe, radeonsi) loads it.  Elements that use LLVM build-depend on
  base/llvm.bst and depend on this.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- filename: base/llvm.bst
  config:
    location: /llvm

depends:
- base/zlib.bst
- base/zstd.bst

config:
  install-commands:
  # libLLVM.so.22.1, and libLLVM-22.so, the name programs link
  - |
    mkdir -p %{install-root}%{libdir}
    cp -a /llvm%{libdir}/libLLVM.so.* /llvm%{libdir}/libLLVM-*.so %{install-root}%{libdir}/
    ls -l %{install-root}%{libdir}

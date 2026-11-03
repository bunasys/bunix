kind: manual
description: |
  Proves the bootstrapped toolchain: C and C++ programs compile, link against
  the final glibc in the multiarch $libdir, and run -- in a sandbox without
  the seed.

build-depends:
- bootstrap/stage3/root.bst
- bootstrap/toolchain.bst

config:
  build-commands:
  - gcc --version | head -1
  - ld --version | head -1
  - |
    echo "multiarch: $(gcc -print-multiarch)"
    echo "libc:      $(gcc -print-file-name=libc.so.6)"
    echo "libstdc++: $(gcc -print-file-name=libstdc++.so)"
  - printf '#include <stdio.h>\nint main(void){puts("hello from bunix C");return 0;}\n' > hello.c
  - gcc -O2 -o hello hello.c && ./hello
  - printf '#include <iostream>\nint main(){std::cout << "hello from bunix C++" << std::endl;}\n' > hello.cpp
  - g++ -O2 -o hellocpp hello.cpp && ./hellocpp
  - readelf -l hello | grep 'interpreter'
  - readelf -d hellocpp | grep NEEDED
  # Nothing the final tools use at run time may point back at the bootstrap:
  # not their code or constant data (where hard-coded search paths live --
  # checked on stripped copies, since debug info rightly names the temporary
  # compiler that built them), and not their RUNPATH.
  - |
    leaks=""
    for f in /usr/bin/gcc /usr/bin/g++ /usr/bin/cpp /usr/bin/ld /usr/bin/as \
             %{libdir}/libc.so.6 %{libdir}/libstdc++.so.6 %{libdir}/libgcc_s.so.1; do
      strip -o stripped "$f"
      if grep -q -a -e '/tools/' -e '/sysroot' -e 'bunix-linux-gnu' stripped; then
        leaks="$leaks $f"
      fi
      if readelf -d "$f" | grep -E 'RPATH|RUNPATH' | grep -q -e /tools -e /sysroot; then
        leaks="$leaks $f(runpath)"
      fi
    done
    if [ -n "$leaks" ]; then echo "bootstrap paths found in:$leaks"; exit 1; fi
    echo "no bootstrap paths in the final toolchain"
  install-commands:
  - install -D -m 0755 hello %{install-root}/usr/share/bunix-tests/hello
  - install -D -m 0755 hellocpp %{install-root}/usr/share/bunix-tests/hellocpp

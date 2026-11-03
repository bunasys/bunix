kind: manual
description: |
  The gcc extension as it is on a running system: the root file system
  with sysext/gcc-tree.bst over it, nothing else.  Builds and runs C and
  C++ programs, one against a system library through pkg-config, and a
  meson project -- with the image's own shell and tools.

build-depends:
- system/rootfs.bst
- sysext/gcc-tree.bst

config:
  build-commands:
  - |
    cat > hello.c <<'EOF'
    #include <stdio.h>
    #include <linux/version.h>
    int main(void) {
        printf("hello from C, kernel headers %d.%d\n",
               LINUX_VERSION_CODE >> 16, (LINUX_VERSION_CODE >> 8) & 0xff);
        return 0;
    }
    EOF
    cc -O2 -Wall -o hello hello.c
    ./hello

  - |
    cat > hello.cpp <<'EOF'
    #include <iostream>
    #include <string>
    int main() { std::string s = "hello from C++"; std::cout << s << '\n'; }
    EOF
    c++ -O2 -o hello-cpp hello.cpp
    ./hello-cpp

  - |
    # a system library through pkg-config: its headers come from the
    # extension, the shared library from the root file system
    cat > tls.c <<'EOF'
    #include <stdio.h>
    #include <openssl/crypto.h>
    int main(void) { printf("linked against %s\n", OpenSSL_version(OPENSSL_VERSION)); return 0; }
    EOF
    cc -o tls tls.c $(pkg-config --cflags --libs openssl)
    ./tls

  - |
    mkdir -p meson-project
    cd meson-project
    printf '%s\n' "project('hello', 'c')" "executable('hello', 'main.c')" > meson.build
    printf '%s\n' '#include <stdio.h>' 'int main(void) { puts("hello from meson"); return 0; }' > main.c
    meson setup build
    ninja -C build
    ./build/hello

  - |
    for cmd in "make --version" "cmake --version" "autoconf --version" \
               "automake --version" "libtool --version" "m4 --version" \
               "ld --version" "as --version"; do
      $cmd | head -1
    done

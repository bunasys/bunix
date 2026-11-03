kind: manual
description: CMake -- the build system libuv, neovim, fish and LLVM use

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:Kitware/CMake/releases/download/v4.4.5/cmake-4.4.5.tar.gz
  ref: a0c54c88abb8078dd8eccadb717fc6bb194bf18e7d44c86309910288886e04e2

config:
  configure-commands:
  # CMake's own bootstrap builds it with nothing but a C++ compiler, using the
  # copies of curl, zlib, expat, libarchive... in its source tree.  Builds
  # here never download, so no TLS; and no curses UI (ccmake).
  - |
    ./bootstrap --prefix=%{prefix} --parallel=%{max-jobs} --no-system-libs -- \
      -DCMAKE_USE_OPENSSL=OFF -DBUILD_CursesDialog=OFF -DBUILD_TESTING=OFF
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install

kind: cmake
description: libzip -- reads zip archives (hyprcursor's cursor themes)

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/zlib.bst
- base/bzip2.bst
- base/xz.bst
- base/zstd.bst
- base/openssl.bst

sources:
- kind: tar
  url: github:nih-at/libzip/releases/download/v1.12.1/libzip-1.12.1.tar.xz
  ref: c40062022a1963c80573d48f6070792297cecd7c6bffe3aefcac0d8b9bee8913

variables:
  cmake-local: >-
    -DBUILD_TOOLS=OFF -DBUILD_REGRESS=OFF -DBUILD_OSSFUZZ=OFF -DBUILD_EXAMPLES=OFF -DBUILD_DOC=OFF
    -DENABLE_GNUTLS=OFF -DENABLE_MBEDTLS=OFF -DENABLE_OPENSSL=ON -DENABLE_COMMONCRYPTO=OFF
    -DENABLE_WINDOWS_CRYPTO=OFF -DENABLE_BZIP2=ON -DENABLE_LZMA=ON -DENABLE_ZSTD=ON

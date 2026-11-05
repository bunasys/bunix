kind: cmake
description: |
  libtiff -- TIFF images, which GTK reads and writes for the clipboard and
  drag and drop; the library only, with JPEG and zlib compression

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

depends:
- base/libjpeg-turbo.bst
- base/zlib.bst

sources:
- kind: tar
  url: https://download.osgeo.org/libtiff/tiff-4.7.2.tar.xz
  ref: 4996f0c4f93094719b1ca5c6279b20e588773ba8a247533e486416fb662ddb88

variables:
  cmake-local: >-
    -Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-contrib=OFF -Dtiff-docs=OFF -Dcxx=OFF
    -Djbig=OFF -Dlerc=OFF -Dlzma=OFF -Dwebp=OFF -Dzstd=OFF -Dlibdeflate=OFF
    -Djpeg=ON -Dzlib=ON

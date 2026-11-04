kind: autotools
description: file and libmagic -- identifies a file's type by its contents

build-depends:
- bootstrap/build-env.bst

depends:
- base/bzip2.bst
- base/xz.bst
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: astron:file/file-5.48.tar.gz
  ref: ed14656883b23a364b4057c05595d93252da9bc473d30106519519d0da141283

variables:
  # -z looks inside compressed files
  conf-local: >-
    --disable-static --disable-libseccomp
    --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --disable-lzlib

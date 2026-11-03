kind: manual
description: bzip2 -- compression tool and library (busybox's build compresses its help text with it)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: sourceware:bzip2/bzip2-1.0.8.tar.gz
  ref: ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269

config:
  # bzip2 has only a Makefile; the shared library has a Makefile of its own
  build-commands:
  - make -f Makefile-libbz2_so CFLAGS="%{cflags} -fPIC -D_FILE_OFFSET_BITS=64"
  - make clean
  - make CFLAGS="%{cflags} -D_FILE_OFFSET_BITS=64" bzip2 bzip2recover
  install-commands:
  - install -D -m 0755 bzip2-shared %{install-root}%{bindir}/bzip2
  - install -m 0755 bzip2recover %{install-root}%{bindir}/
  - ln -s bzip2 %{install-root}%{bindir}/bunzip2
  - ln -s bzip2 %{install-root}%{bindir}/bzcat
  - install -D -m 0644 bzlib.h %{install-root}%{includedir}/bzlib.h
  - install -D -m 0755 libbz2.so.1.0.8 %{install-root}%{libdir}/libbz2.so.1.0.8
  - ln -s libbz2.so.1.0.8 %{install-root}%{libdir}/libbz2.so.1.0
  - ln -s libbz2.so.1.0.8 %{install-root}%{libdir}/libbz2.so

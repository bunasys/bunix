unpack $src
# bzip2 has two makefiles and no install step that knows of a library
# directory.  The shared library first, and the program that uses it; then
# bzip2recover from the other makefile.
make -f Makefile-libbz2_so CFLAGS="$CFLAGS -fPIC -D_FILE_OFFSET_BITS=64"
make clean
make CFLAGS="$CFLAGS -D_FILE_OFFSET_BITS=64" bzip2recover

install -D -m 755 bzip2-shared $out/usr/bin/bzip2
install -m 755 bzip2recover $out/usr/bin/
ln -s bzip2 $out/usr/bin/bunzip2
ln -s bzip2 $out/usr/bin/bzcat
install -D -m 644 bzlib.h $out/usr/include/bzlib.h
install -D -m 755 libbz2.so.1.0.8 $out/usr/lib/$triplet/libbz2.so.1.0.8
ln -s libbz2.so.1.0.8 $out/usr/lib/$triplet/libbz2.so.1.0
ln -s libbz2.so.1.0.8 $out/usr/lib/$triplet/libbz2.so

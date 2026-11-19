unpack $src
# LZ4 has a makefile and no configure.
make
make PREFIX=/usr LIBDIR=/usr/lib/$triplet DESTDIR=$out install
rm $out/usr/lib/$triplet/liblz4.a

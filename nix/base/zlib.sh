unpack $src
# zlib's configure is its own, not autoconf's, and stops at an option it
# does not know.
./configure --prefix=/usr --libdir=/usr/lib/$triplet
make
make DESTDIR=$out install
rm $out/usr/lib/$triplet/libz.a

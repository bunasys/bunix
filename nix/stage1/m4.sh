unpack $src
./configure --prefix=$out CC="$CC"
make
make install

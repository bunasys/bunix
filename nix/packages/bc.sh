unpack $src
# bc's configure is its own, not autoconf's.  -G: no generated tests, they
# need a bc to exist already.
CC='gcc -std=c99' ./configure --prefix=$out -G -O2
make
make install

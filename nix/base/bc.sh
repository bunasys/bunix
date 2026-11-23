unpack $src
# bc's configure is its own, not autoconf's.  -G: no generated tests, they
# need a bc to exist already.  -std=c99: bc is written to that standard,
# and newer ones turn some of what it does into errors.
CC='gcc -std=c99' ./configure --prefix=/usr -G -O2
make
make DESTDIR=$out install

# The usual three steps, for a package that needs nothing else.
# $configure_flags is what the package adds to ./configure (stage2.nix).
unpack $src
./configure --prefix=$out ${configure_flags:-}
make
make install

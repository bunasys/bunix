# The usual three steps, for a package that needs nothing else.
#
# $configure_arguments is what the package adds to ./configure.  It is
# split at spaces, so it cannot carry an argument that has one in it
# (INSTALL="install -c"): a package that needs such an argument has a
# script of its own.
unpack $src
./configure --prefix=$out ${configure_arguments:-}
make
make install

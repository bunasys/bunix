# For a system package that is configured, built and installed the usual
# way and needs nothing else: what `kind: autotools` is to a .bst element.
#
# $configure_arguments is what the package adds to ./configure (conf-local
# in a .bst element).  It is split at spaces, so it cannot carry an
# argument that has one in it: a package that needs such an argument, or
# another step, has a script of its own with these four lines in it.
unpack $src
./configure $configure_for_usr ${configure_arguments:-}
make
make DESTDIR=$out install

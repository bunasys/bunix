unpack $src
# Its own makefiles, with UAPI.9's directories in place of theirs
# (/usr/lib64), and no manual pages: they are made with mandoc, which
# bunix does not have.
make_arguments="PREFIX=/usr LIBDIR=/usr/lib/$triplet BINDIR=/usr/bin ENABLE_DOCS=0"
make -j$jobs $make_arguments
make $make_arguments DESTDIR=$out install

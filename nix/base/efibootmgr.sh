unpack $src
# Its own makefiles, with UAPI.9's directories in place of theirs.
# EFIDIR: the directory on an ESP that a distribution's loader is in,
# which it must be told; bunix's is EFI/bunix (bunix-install).
make_arguments="prefix=/usr libdir=/usr/lib/$triplet sbindir=/usr/bin EFIDIR=bunix"
make -j$jobs $make_arguments
make $make_arguments DESTDIR=$out install

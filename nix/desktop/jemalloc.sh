# ../autotools.sh's lines
unpack $src
./configure $configure_for_usr --disable-static
make
make DESTDIR=$out install
# Its programs are scripts for profiling and for building against it,
# which the system has no use for (jeprof is Perl, which it has not):
# Quickshell only links the library
rm -r $out/usr/bin

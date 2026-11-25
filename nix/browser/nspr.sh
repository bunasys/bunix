unpack $src
# ../autotools.sh's lines, in nspr/: the tarball's top directory holds
# only that.  64-bit, threads, optimized (as 0.4.0's element).
cd nspr
./configure $configure_for_usr --enable-64bit --with-pthreads --enable-optimize --disable-debug
make
make DESTDIR=$out install
# Static libraries, NSPR's error-table tools, and nspr-config (a shell
# script: what builds against NSPR asks pkg-config, nspr.pc), which
# nothing here uses
rm $out/usr/lib/$triplet/*.a $out/usr/bin/compile-et.pl $out/usr/bin/prerr.properties     $out/usr/bin/nspr-config

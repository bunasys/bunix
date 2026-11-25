unpack $src
# ../autotools.sh's lines.  No Python module, ICU or LZMA (as 0.4.0's
# element).
./configure $configure_for_usr --disable-static --without-python --without-icu --without-debug --with-zlib --without-lzma
make
make DESTDIR=$out install
# xml2-config, a shell script: what builds against libxml2 asks
# pkg-config (libxml-2.0.pc), and nothing here uses it
rm $out/usr/bin/xml2-config

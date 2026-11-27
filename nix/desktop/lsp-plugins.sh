# lsp-plugins as LV2 plugins and nothing else (FEATURES): no windows,
# which would want X11 and OpenGL, no other plugin formats, no programs
# and no documentation.  Its own make files, configured once (`make
# config`), with the system's compiler.  Into /usr/lib/<triplet>/lv2,
# where lilv looks.
unpack $src
features=lv2
make config FEATURES=$features PREFIX=/usr LIBDIR=/usr/lib/$triplet CC=gcc CXX=g++
make -j$jobs
make install FEATURES=$features DESTDIR=$out
# where lilv looks, or the build fails here rather than the chain on a Mac
[ -f $out/usr/lib/$triplet/lv2/lsp-plugins.lv2/manifest.ttl ]

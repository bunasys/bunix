unpack $src
# CMake's bootstrap builds a small cmake, which then configures the real
# one; what follows `--` is for that.
# --no-system-libs: its own copies of curl, zlib, libuv and the rest, so
#   that a build tool needs nothing of the system.
# --docdir: its default is /usr/doc.
# CMAKE_USE_OPENSSL=OFF: no downloads over TLS from inside a build.
./bootstrap --prefix=/usr --docdir=share/doc/cmake --parallel=$jobs --no-system-libs -- \
    -DCMAKE_USE_OPENSSL=OFF -DBUILD_CursesDialog=OFF -DBUILD_TESTING=OFF
make
make DESTDIR=$out install

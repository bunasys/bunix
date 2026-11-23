# For a system package that CMake configures and ninja builds, and that
# needs nothing else: what `kind: cmake` is to a .bst element, as
# autotools.sh and meson.sh are for theirs.  (base/cmake.sh is something
# else: it builds CMake itself.)
#
# $cmake_arguments is what the package adds (cmake-local in a .bst
# element), split at spaces.  The arguments before it put things where
# UAPI.9 has them.
unpack $src
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib/$triplet \
    -DCMAKE_INSTALL_SBINDIR=bin -DCMAKE_INSTALL_LIBEXECDIR=lib \
    -DCMAKE_INSTALL_SYSCONFDIR=/etc -DCMAKE_INSTALL_LOCALSTATEDIR=/var \
    ${cmake_arguments:-}
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

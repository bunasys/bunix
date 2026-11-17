unpack $src
# INSTALL, MKDIR_P, CXX: Python keeps its build settings, for building
# modules later; by name, not the paths configure would find (stage2.nix).
./configure --prefix=$out --without-ensurepip --disable-test-modules \
    INSTALL="install -c" MKDIR_P="mkdir -p" CXX=g++
make
make install

unpack $src

# Not static, as the other tools of this stage are: Python loads its own
# modules as shared libraries.  It is linked against the seed's glibc
# instead, with the loader and the libraries named by their paths, because
# the loader a program asks for by default (in /lib) does not exist here.
seed_libraries=$seed/sysroot/usr/lib
seed_loader=$(echo $seed_libraries/ld-linux-*.so.*)

./configure --prefix=$out --without-ensurepip --disable-test-modules \
    LDFLAGS="-Wl,--dynamic-linker=$seed_loader -Wl,-rpath,$seed_libraries"
make
make install

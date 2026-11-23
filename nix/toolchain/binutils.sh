unpack $src
mkdir build
cd build

# $for_usr_glibc: compiled by stage 1's gcc, for the system's glibc
# (toolchain.nix)

# stage 2 has no makeinfo; the tarball ships its manuals already built
export MAKEINFO=true

# --enable-plugins: gcc's link-time optimisation is a plugin of ld's
# --enable-shared: libbfd and its companions as libraries in /usr/lib/$triplet
# tooldir: without it, a second copy of each program in /usr/$triplet/bin
../configure \
    CC="gcc $for_usr_glibc" CXX="g++ $for_usr_glibc" \
    --build=$triplet --host=$triplet --target=$triplet \
    --prefix=/usr --libdir=/usr/lib/$triplet --sysconfdir=/etc \
    --with-lib-path=/usr/lib/$triplet:/usr/lib \
    --enable-ld=default --enable-plugins --enable-shared --disable-static \
    --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu \
    --enable-gprofng=no --disable-nls --disable-werror \
    --enable-deterministic-archives
make tooldir=/usr
make DESTDIR=$out tooldir=/usr install

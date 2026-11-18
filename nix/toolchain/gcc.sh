unpack $src
unpack $gmp gmp
unpack $mpfr mpfr
unpack $mpc mpc

# gcc's own run-time libraries (libgcc_s, libstdc++...) go where glibc's
# are, /usr/lib/$triplet, not in lib64.  gcc's private files and its
# internal programs stay under /usr/lib/gcc/ (UAPI.9 has no /usr/libexec).
case $system in
    aarch64-linux)
        library_directories=gcc/config/aarch64/t-aarch64-linux
        sed -e "/lp64=/s|\.\./lib64|../lib/$triplet|" -i $library_directories
        ;;
    x86_64-linux)
        library_directories=gcc/config/i386/t-linux64
        sed -e "/m64=/s|\.\./lib64|../lib/$triplet|" -i $library_directories
        ;;
    *) echo "gcc.sh: gcc's configuration files for $system are not known" >&2; exit 1 ;;
esac
# a sed that matches nothing succeeds: make sure lib64 is gone
if grep -E '(lp64|m64)=.*lib64' $library_directories; then
    echo "gcc.sh: lib64 is still in $library_directories" >&2
    exit 1
fi

mkdir build
cd build

# stage 2 has no makeinfo; the tarball ships its manuals already built
export MAKEINFO=true

# --enable-multiarch: gcc looks for headers and libraries in the
#   directories named after the architecture.
# --disable-bootstrap: gcc does not build itself three times over here.
#   The stages are that already: the seed's gcc built stage 1's, which
#   builds this one, all from the same source.
# --enable-host-pie: gcc's own programs are position-independent, as what
#   it builds is by default (--enable-default-pie).
# --disable-fixincludes: gcc would copy and "fix" system headers it finds
#   fault with; glibc's need none.
# --disable-libcc1: a C++ shared library, which stage 1's gcc cannot link.
../configure \
    CC="gcc $for_usr_glibc" CXX="g++ $for_usr_glibc" \
    --build=$triplet --host=$triplet --target=$triplet \
    --prefix=/usr --libexecdir=/usr/lib --enable-languages=c,c++ \
    --enable-default-pie --enable-default-ssp --enable-host-pie \
    --enable-multiarch --disable-multilib --disable-bootstrap \
    --disable-fixincludes --disable-nls --disable-libcc1
make
make DESTDIR=$out install
ln -s gcc $out/usr/bin/cc

# install-tools re-creates gcc's fixed headers for a changed system; it is
# not used, and records the shell that built it, which is the bootstrap's.
rm -rf $out/usr/lib/gcc/$triplet/*/install-tools

# ar, nm and ranlib look for plugins in one directory of binutils'; gcc's
# plugin for link-time optimisation goes there, so that they can read the
# objects it makes.
mkdir -p $out/usr/lib/$triplet/bfd-plugins
plugin=$(cd $out/usr/lib && echo gcc/$triplet/*/liblto_plugin.so)
ln -s ../../$plugin $out/usr/lib/$triplet/bfd-plugins/
[ -e $out/usr/lib/$triplet/bfd-plugins/liblto_plugin.so ]

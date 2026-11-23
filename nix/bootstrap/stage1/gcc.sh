unpack $src
unpack $gmp gmp
unpack $mpfr mpfr
unpack $mpc mpc

# The two files of gcc's source that say where things are on this
# architecture.  The first has gcc look for 64-bit libraries in lib64;
# glibc's are in lib.  The second is changed below.
case $system in
    aarch64-linux)
        library_directories=gcc/config/aarch64/t-aarch64-linux
        sed -e '/lp64=/s/lib64/lib/' -i $library_directories
        target_header=gcc/config/aarch64/aarch64-linux.h
        ;;
    x86_64-linux)
        library_directories=gcc/config/i386/t-linux64
        sed -e '/m64=/s/lib64/lib/' -i $library_directories
        target_header=gcc/config/i386/linux64.h
        ;;
    *) echo "gcc.sh: gcc's configuration files for $system are not known" >&2; exit 1 ;;
esac
# a sed that matches nothing succeeds: make sure lib64 is gone
if grep -E '(lp64|m64)=.*lib64' $library_directories; then
    echo "gcc.sh: lib64 is still in $library_directories" >&2
    exit 1
fi

# gcc expects glibc's loader in /lib and its start files (crt1.o...) in /lib
# or /usr/lib.  Here glibc is in the store, and gcc is told where, so that
# a plain `gcc hello.c` gives a program that runs, with no flags.
# [0-9]*: the loader is in /lib on aarch64, in /lib64 on x86_64
sed -i "s|\"/lib[0-9]*/ld-linux|\"$glibc/lib/ld-linux|" $target_header
grep -q "\"$glibc/lib/ld-linux" $target_header
cat >> $target_header <<END
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "$glibc/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""
END

mkdir build
cd build

# the seed has no makeinfo; the tarball ships its manuals already built
export MAKEINFO=true

# --disable-bootstrap: gcc is not rebuilt with itself here; stage 3 does that.
# No LTO and no shared libgcc or libstdc++: this gcc is a static program,
# as the seed's is.  stage1.nix says what that costs.
# --with-local-prefix: without it gcc also searches /usr/local/include.
../configure \
    CC="$CC" CXX="$CXX" \
    --prefix=$out --with-local-prefix=$out \
    --with-native-system-header-dir=$glibc/include \
    --with-as=$binutils/bin/as --with-ld=$binutils/bin/ld \
    --disable-bootstrap \
    --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib \
    --disable-shared --disable-lto --disable-plugin --disable-libcc1 \
    --disable-libatomic --disable-libgomp --disable-libquadmath \
    --disable-libsanitizer --disable-libssp --disable-libvtv \
    --disable-libstdcxx-pch \
    --enable-languages=c,c++
make
make install
ln -s gcc $out/bin/cc

# install-tools re-creates gcc's fixed headers for a changed system, which
# does not happen in a store.  One of its programs records the shell that
# built it, and that alone would make this gcc depend on the seed.
rm -r $out/libexec/gcc/*/*/install-tools $out/lib/gcc/*/*/install-tools

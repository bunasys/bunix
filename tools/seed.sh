#!/bin/bash
# A seed: what the Nix store of one architecture starts from (stage 0).
#
#   tools/seed.sh aarch64
#   tools/seed.sh x86_64
#
# Cross-compiled on an x86_64 bunix machine, by bunix's own gcc, following
# elements/bootstrap/ stage 1 (a cross toolchain) and stage 2 (tools that
# run on the target).  The x86_64 seed is cross-compiled too, as the
# bootstrap is: its triplet differs from this machine's in the vendor
# field, so nothing of this machine's is picked up by accident.
#
#   ~/seed-<arch>/host     gawk and bison for this machine (glibc's build needs them)
#   ~/seed-<arch>/cross    binutils and gcc that run here and produce the seed's code
#   ~/seed-<arch>/dest/seed  the seed itself, packed as bunix-seed-<arch>.tar.xz
#
# The seed differs from stage 2 in three ways.  The first two are because a
# Nix build starts with nothing but /nix/store, at a path not known until
# the seed is unpacked:
#
# - every program is statically linked: there is no dynamic loader to find;
# - gcc and ld are configured with their sysroot (glibc and the kernel
#   headers, in /seed/sysroot) inside their prefix (/seed), which makes
#   both look for headers and libraries relative to where they are,
#   wherever that is.  A sysroot equal to the prefix does not work: the
#   path arithmetic compares "seed" with "seed/" and finds them different;
# - it is smaller: no m4, file or ncurses, and no bison or Python.  Stage 1
#   in Nix builds what it needs of these with the seed's gcc.
#
# It runs on a bunix 0.4.0 machine with the gcc extension.
#
# A step that succeeded is not run again, which is for working on this
# script: remove ~/seed-<arch>/done/<step> to repeat one.  Each step's
# output is in ~/seed-<arch>/log/<step>.log.  A seed that is published is
# built from an empty ~/seed-<arch> (keeping src/ is fine): a repeated
# step installs over what the earlier run left in dest/.
set -euo pipefail
umask 022

# The tarball is the same only when built at the same path, so by the same
# user: gcc records its configure line, and that names the directories below.
arch=${1:?usage: seed.sh aarch64|x86_64}
work=$HOME/seed-$arch
seed=$work/dest/seed
sysroot=$seed/sysroot
cross=$work/cross
target=$arch-bunix-linux-gnu

# What differs by architecture: the kernel's name for it, and the file of
# gcc's source that puts 64-bit libraries in lib64 (the seed has one
# architecture, they go in lib).
case $arch in
    aarch64)
        kernel_arch=arm64
        gcc_library_directories=gcc/config/aarch64/t-aarch64-linux
        ;;
    x86_64)
        kernel_arch=x86_64
        gcc_library_directories=gcc/config/i386/t-linux64
        ;;
    *) echo "seed.sh: unknown architecture $arch" >&2; exit 1 ;;
esac

export LC_ALL=C TZ=UTC
export PATH=$cross/bin:$work/host/bin:/usr/bin
export MAKEFLAGS=-j$(nproc)
# this machine has no makeinfo; the tarballs ship their manuals already built
export MAKEINFO=true
# the release date of bunix 0.4.0: the time of every file in the tarball
export SOURCE_DATE_EPOCH=$(date -u -d 2026-11-14 +%s)

build=$(gcc -dumpmachine)

# The same versions and checksums as elements/bootstrap/.  A version is
# written here only: the steps below name packages, not versions, except
# for the two that gcc's and glibc's configure lines need.
gcc_version=16.2.0
glibc_version=2.44
sources="
154ab23b60070e8f27013c22977f1129425d67d1e8acd6e13010e617811e4cff  https://mirrors.kernel.org/gnu/binutils/binutils-2.47.tar.xz
e6738e29597f733270731aa90600f37ffdc045079dfc27ec7e8192cc81085c3e  https://mirrors.kernel.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.xz
a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898  https://mirrors.kernel.org/gnu/gmp/gmp-6.3.0.tar.xz
b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01  https://mirrors.kernel.org/gnu/mpfr/mpfr-4.2.2.tar.xz
91204cd32f164bd3b7c992d4a6a8ce6519511aadab30f78b6982d0bf8d73e931  https://mirrors.kernel.org/gnu/mpc/mpc-1.4.1.tar.xz
37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667  https://mirrors.kernel.org/gnu/glibc/glibc-$glibc_version.tar.xz
2b69564f7d4fea0c859b1959ba33709ee6e9139bd100e30a853b57159a8221b8  https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.18.52.tar.xz
0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba  https://mirrors.kernel.org/gnu/bash/bash-5.3.tar.gz
a480198559733e9b3da999e90543ac6f888a2caa544d8d664c5a1f17e528e210  https://mirrors.kernel.org/gnu/coreutils/coreutils-9.12.tar.xz
b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7  https://mirrors.kernel.org/gnu/sed/sed-4.10.tar.xz
f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc  https://mirrors.kernel.org/gnu/gawk/gawk-5.3.2.tar.xz
2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9  https://mirrors.kernel.org/gnu/grep/grep-3.12.tar.xz
4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16  https://mirrors.kernel.org/gnu/tar/tar-1.35.tar.xz
4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b  https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.xz
9aa0cc780dec156b8282844833b342ab7cb08c25d2cd9a1869cdd0df31deff48  https://mirrors.kernel.org/gnu/gzip/gzip-1.15.tar.xz
3240c7959c5347c8ed347e3c4201c0337bf4240d5cf09d68889e58eeaba30e17  https://mirrors.kernel.org/gnu/patch/patch-2.8.1.tar.xz
bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd  https://mirrors.kernel.org/gnu/findutils/findutils-4.11.0.tar.xz
7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd  https://mirrors.kernel.org/gnu/diffutils/diffutils-3.12.tar.xz
dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3  https://mirrors.kernel.org/gnu/make/make-4.4.1.tar.gz
9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2  https://mirrors.kernel.org/gnu/bison/bison-3.8.2.tar.xz
"

mkdir -p "$work"/{src,build,log,done,host} "$seed"

current=fetch
report_failure() {
    echo "FAILED: $current" >&2
    [ ! -e "$work/log/$current.log" ] || tail -n 40 "$work/log/$current.log" >&2
}
trap '[ $? -eq 0 ] || report_failure' EXIT

echo "$sources" | while read -r sha256 url; do
    [ -n "$url" ] || continue
    file=$work/src/${url##*/}
    [ ! -e "$file" ] || continue
    # --retry-all-errors: a connection reset mid-download is not one of
    # the errors --retry alone repeats; -C - resumes the partial file
    curl -fsSL --retry 5 --retry-all-errors -C - -o "$file.part" "$url"
    # checked before it gets its name, so a bad download is fetched again
    # by the next run instead of failing every one
    if ! echo "$sha256  $file.part" | sha256sum --check --quiet; then
        rm "$file.part"
        exit 1
    fi
    mv "$file.part" "$file"
done

# step <name> <command...>: runs the command once, in an empty build
# directory, with its output in log/<name>.log.
step() {
    current=$1
    shift
    [ ! -e "$work/done/$current" ] || return 0
    echo "== $current"
    rm -rf "$work/build/$current"
    mkdir -p "$work/build/$current"
    (cd "$work/build/$current"; "$@") > "$work/log/$current.log" 2>&1
    rm -rf "$work/build/$current"
    touch "$work/done/$current"
}

# unpack <package> [directory]: the package's source, without its top
# directory, into the current directory or the one named.
unpack() {
    mkdir -p "${2:-.}"
    tar -xf "$work"/src/"$1"-[0-9]*.tar.* --strip-components=1 -C "${2:-.}"
}

unpack_gcc() {
    unpack gcc
    unpack gmp gmp
    unpack mpfr mpfr
    unpack mpc mpc
    sed -E -e '/(lp64|m64)=/s/lib64/lib/' -i $gcc_library_directories
}

# ---- Tools for this machine --------------------------------------------

host_gawk() {
    unpack gawk
    # the extras (the awk profile scripts for login shells) are not needed
    sed -i 's/extras//' Makefile.in
    ./configure --prefix="$work/host"
    make
    make install
}

host_bison() {
    unpack bison
    ./configure --prefix="$work/host"
    make
    make install
}

step host-gawk host_gawk
step host-bison host_bison

# ---- Stage 1: the cross toolchain, and glibc for the seed ---------------

cross_binutils() {
    unpack binutils
    mkdir build
    cd build
    # deterministic archives: no file times or owners in libc.a and libgcc.a,
    # which this ar creates and the seed ships
    ../configure \
        --prefix="$cross" --target=$target --with-sysroot="$sysroot" \
        --with-lib-path==/usr/lib \
        --disable-nls --enable-gprofng=no --disable-werror \
        --enable-new-dtags --enable-default-hash-style=gnu \
        --enable-deterministic-archives
    make
    make install
}

# Pass 1: just enough C/C++ compiler to build glibc -- no libc headers yet,
# so no shared libgcc, threads or libstdc++.
cross_gcc() {
    unpack_gcc
    mkdir build
    cd build
    ../configure \
        --target=$target --prefix="$cross" --with-sysroot="$sysroot" \
        --with-glibc-version=$glibc_version --with-newlib --without-headers \
        --enable-default-pie --enable-default-ssp --disable-nls \
        --disable-shared --disable-multilib --disable-threads \
        --disable-libatomic --disable-libgomp --disable-libquadmath \
        --disable-libssp --disable-libvtv --disable-libstdcxx \
        --enable-languages=c,c++
    make
    make install
    # Built --without-headers, gcc installed a limits.h for a system without
    # a libc; glibc needs the full one
    gcc_include=$(dirname "$("$cross/bin/$target-gcc" -print-libgcc-file-name)")/include
    cat ../gcc/limitx.h ../gcc/glimits.h ../gcc/limity.h > "$gcc_include/limits.h"
}

linux_headers() {
    unpack linux
    make ARCH=$kernel_arch headers
    find usr/include -type f ! -name '*.h' -delete
    mkdir -p "$sysroot/usr"
    cp -r usr/include "$sysroot/usr/"
}

glibc() {
    unpack glibc
    mkdir build
    cd build
    echo "rootsbindir=/usr/bin" > configparms
    # --enable-kernel: as in project.conf (glibc-min-kernel)
    ../configure \
        --prefix=/usr --libdir=/usr/lib \
        --host=$target --build="$build" \
        --with-headers="$sysroot/usr/include" --enable-kernel=5.4 \
        --disable-nscd --disable-werror \
        libc_cv_slibdir=/usr/lib
    make
    make DESTDIR="$sysroot" install
}

# libstdc++ for the cross compiler, now that glibc exists: gcc itself is
# C++, so pass 2 needs it.  It goes beside the cross compiler, not in the
# seed: the seed gets pass 2's own.
cross_libstdcxx() {
    unpack gcc
    mkdir build
    cd build
    ../libstdc++-v3/configure \
        --host=$target --build="$build" \
        --prefix="$cross/$target" \
        --disable-multilib --disable-nls --disable-libstdcxx-pch --disable-shared \
        --with-gxx-include-dir="$cross/$target/include/c++/$gcc_version"
    make
    make install
    find "$cross/$target" -name '*.la' -delete
}

step cross-binutils cross_binutils
step cross-gcc cross_gcc
step linux-headers linux_headers
step glibc glibc
step cross-libstdcxx cross_libstdcxx

# ---- Stage 2: the seed's programs, static --------------------------------

# build_seed_tool [configure arguments]: the autotools package unpacked in
# the current directory, static, into the seed.
build_seed_tool() {
    # --static, not -static: libtool keeps -static for itself and links libc
    # dynamically; --static it passes on to gcc.
    # gl_cv_func_working_mktime: a cross build cannot run the test, assumes
    # mktime is broken and brings its own, which then collides with glibc's
    # in a static link.
    ./configure --prefix=/seed --host=$target --build="$build" LDFLAGS=--static \
        gl_cv_func_working_mktime=yes "$@"
    make
    make DESTDIR="$work/dest" install
}

seed_tool() {
    unpack "$1"
    shift
    build_seed_tool "$@"
}

seed_gawk() {
    unpack gawk
    # the extras (the awk profile scripts for login shells) are not needed
    sed -i 's/extras//' Makefile.in
    build_seed_tool
}

seed_gzip() {
    unpack gzip
    # gzip.h defines a macro named `head`, and on aarch64 the kernel's
    # signal structures have a member of that name: <signal.h> must come
    # before gzip.h, not after
    sed -i 's/^#include "tailor.h"/#include <signal.h>\n&/' gzip.c
    build_seed_tool
}

step bash seed_tool bash --without-bash-malloc --enable-static-link
# no stdbuf: it works through a shared library, which cannot be linked static
step coreutils seed_tool coreutils --enable-install-program=hostname --enable-no-install-program=kill,uptime,stdbuf
step sed seed_tool sed
step grep seed_tool grep
step gawk seed_gawk
step findutils seed_tool findutils
step diffutils seed_tool diffutils gl_cv_func_strcasecmp_works=y
step make seed_tool make --without-guile
step patch seed_tool patch
step tar seed_tool tar
step gzip seed_gzip
step xz seed_tool xz --disable-shared

seed_binutils() {
    unpack binutils
    mkdir build
    cd build
    # no plugins: a static ld cannot load them
    ../configure \
        --prefix=/seed --build="$build" --host=$target \
        --with-sysroot=/seed/sysroot --with-lib-path==/usr/lib \
        --disable-nls --disable-shared --disable-plugins \
        --enable-gprofng=no --disable-werror \
        --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu \
        --enable-deterministic-archives \
        LDFLAGS=--static
    make
    make DESTDIR="$work/dest" install
}

# Pass 2: gcc that runs on the seed's architecture.  No LTO: it needs a linker plugin.
# Its libstdc++ and libgcc are static only, so what the seed builds does
# not depend on a shared library of the seed's by accident.
seed_gcc() {
    unpack_gcc
    # glibc now exists, so libgcc and libstdc++ can use POSIX threads
    sed '/thread_header =/s/@.*@/gthr-posix.h/' -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
    mkdir build
    cd build
    ../configure \
        --build="$build" --host=$target --target=$target \
        LDFLAGS=--static LDFLAGS_FOR_TARGET="-L$PWD/$target/libgcc" \
        --prefix=/seed --with-sysroot=/seed/sysroot --with-build-sysroot="$sysroot" \
        --enable-default-pie --enable-default-ssp --disable-nls --disable-multilib \
        --disable-shared --disable-lto --disable-plugin --disable-libcc1 \
        --disable-libatomic --disable-libgomp --disable-libquadmath \
        --disable-libsanitizer --disable-libssp --disable-libvtv \
        --enable-languages=c,c++
    make
    make DESTDIR="$work/dest" install
}

step seed-binutils seed_binutils
step seed-gcc seed_gcc

# ---- The tarball --------------------------------------------------------

current=finish
ln -sf bash "$seed/bin/sh"
ln -sf gcc "$seed/bin/cc"
rm -rf "$seed"/share/{man,info,doc,locale} "$sysroot"/usr/share/{man,info,doc,locale}
# glibc's own programs (iconv, locale, getconf...) are dynamically linked,
# to a loader path that does not exist in a Nix build: they cannot run there
rm -rf "$sysroot"/usr/{bin,sbin,libexec}
find "$seed" -name '*.la' -delete

current=check-static
programs=$(find "$seed/bin" "$seed/libexec" "$seed/$target/bin" -type f -exec file {} + | grep ELF)
not_static=$(echo "$programs" | grep -v -E 'statically linked|static-pie linked' || true)
if [ -n "$not_static" ]; then
    echo "not statically linked:" >&2
    echo "$not_static" >&2
    exit 1
fi

# Debugging information is most of the seed's size, and names the build
# directory in every file that has it.
current=strip
echo "$programs" | cut -d: -f1 | xargs "$target-strip" --strip-unneeded
find "$seed" -type f \( -name '*.so' -o -name '*.so.*' \) -exec file {} + \
    | grep 'ELF.*shared object' | cut -d: -f1 \
    | xargs "$target-strip" --strip-unneeded
# not every .a is an archive: glibc's libm.a is a linker script
find "$seed" -type f \( -name '*.a' -o -name '*.o' \) -exec file {} + \
    | grep -E 'ar archive|ELF.*relocatable' | cut -d: -f1 \
    | xargs "$target-strip" --strip-debug

# Under a temporary name first: an interrupted run leaves no half-written
# file where a finished tarball is expected.
current=pack
tarball=$work/bunix-seed-$arch.tar.xz
tar -C "$seed" --sort=name --mtime="@$SOURCE_DATE_EPOCH" \
    --owner=0 --group=0 --numeric-owner -cf - . | xz -6 -T1 > "$tarball.tmp"
mv "$tarball.tmp" "$tarball"
sha256sum "$tarball"

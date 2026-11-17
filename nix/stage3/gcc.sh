# The final gcc.  Four jobs, in this order:
#
#   1. tell gcc's source where glibc is in the store
#   2. configure and build
#   3. move the shared libraries to an output of their own, $lib
#   4. write the `specs` file that makes programs find those libraries
#
# Job 1 is stage1/gcc.sh's, line for line: a change to one is a change to
# both.

# ---- 1. Where glibc is --------------------------------------------------

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

# ---- 2. Configure and build ---------------------------------------------

mkdir build
cd build

# stage 2 has no makeinfo; the tarball ships its manuals already built
export MAKEINFO=true

# This gcc is compiled by stage 1's, which links for stage 1's glibc.  It
# has to be a program of this stage's glibc: its start files, its
# libraries and its loader.  The headers need no flag: both glibcs are the
# same version, and their headers the same files.
loader=$(echo $glibc/lib/ld-linux-*.so.*)
for_this_glibc="-B$glibc/lib -Wl,--dynamic-linker=$loader"

# LDFLAGS_FOR_TARGET: the flags gcc's own libraries are linked with.  They
# record where they will be (job 3), because they need each other:
#   libstdc++.so needs libgcc_s.so, and has to find it itself when the
#   program that loads it does not need libgcc_s.
# --disable-bootstrap: gcc does not build itself three times over here.
#   The stages are that already: the seed's gcc built stage 1's, which
#   builds this one, all from the same source.
# --enable-host-pie: gcc's own programs are position-independent, as what
#   it builds is by default (--enable-default-pie).
# --disable-fixincludes: gcc would copy and "fix" system headers it finds
#   fault with; glibc's need none.
# --disable-libcc1: a C++ shared library, which stage 1's gcc cannot link.
# --disable-libsanitizer, --disable-libvtv: these libraries need libstdc++,
#   and libtool links them with the path of gcc's lib/ in them to find it.
#   After job 3 that path is the compiler's, and gcc.lib would depend on
#   the compiler (the check at the end of job 3).  Until that path can be
#   corrected, there are no sanitizers.
# --with-local-prefix: without it gcc also searches /usr/local/include.
../configure \
    CC="gcc $for_this_glibc" CXX="g++ $for_this_glibc" \
    LDFLAGS_FOR_TARGET="-Wl,-rpath,$lib/lib" \
    --prefix=$out --with-local-prefix=$out \
    --with-native-system-header-dir=$glibc/include \
    --with-as=$binutils/bin/as --with-ld=$binutils/bin/ld \
    --disable-bootstrap --enable-languages=c,c++ \
    --enable-default-pie --enable-default-ssp --enable-host-pie \
    --disable-multilib --disable-fixincludes --disable-nls --disable-libcc1 \
    --disable-libsanitizer --disable-libvtv
make
make install
ln -s gcc $out/bin/cc

# install-tools re-creates gcc's fixed headers for a changed system, which
# does not happen in a store, and records the shell that built it.
rm -r $out/libexec/gcc/*/*/install-tools $out/lib/gcc/*/*/install-tools

# ---- 3. The shared libraries, in $lib -----------------------------------
#
# A program built by this gcc needs libstdc++.so or libgcc_s.so to run, not
# the compiler.  The shared libraries move to an output of their own, and
# gcc's lib/ keeps links to them, for the linker to find.

# Scripts for gdb, named after libstdc++.so so that the loop below would
# take them along; they name gcc's own path.
rm $out/lib/*-gdb.py

mkdir -p $lib/lib
for library in $out/lib/lib*.so*; do
    mv $library $lib/lib/
    ln -s $lib/lib/$(basename $library) $out/lib/
done

# The libraries may not name the compiler's path: a program that needs
# them would need all of gcc again, and Nix refuses two outputs that each
# need the other.
if grep -r -l $out $lib; then
    echo "gcc.sh: the files above, in gcc.lib, name gcc's own path" >&2
    exit 1
fi

# ---- 4. The specs file --------------------------------------------------
#
# gcc decides how to run the linker by rules it calls specs.  If there is
# a file `specs` beside its libgcc.a, gcc reads its rules from it and does
# not prepare the ones built in: the file has to hold them all.  So it is
# what `gcc -dumpspecs` prints, followed by two additions.  In a specs
# file:
#
#   *name:        the rule to change
#   + text        text to add to the end of that rule
#   %{!flag:X}    X, unless gcc was given -flag
#
# The two additions below are for whatever is linked dynamically (not
# -static, not -static-pie).
#
# link: on every run of the linker, except to combine object files (-r).
#   The path of the libraries above goes into the program or library
#   (-rpath): they are in no directory the loader looks in by itself.
#
# link_gcc_c_sequence: where gcc adds its own libraries and libc, so not
#   with -nostdlib.  libgcc_s.so is linked whether the program calls into
#   it or not (--no-as-needed, for this one library).  glibc loads it when
#   a thread is cancelled or calls pthread_exit, by name alone, and finds
#   it only if the program has it loaded already.
specs=$(dirname $($out/bin/gcc -print-libgcc-file-name))/specs
$out/bin/gcc -dumpspecs > $specs
cat >> $specs <<END
*link:
+ %{!static:%{!static-pie:%{!r:-rpath $lib/lib}}}

*link_gcc_c_sequence:
+ %{!static:%{!static-pie:%{!static-libgcc:--push-state --no-as-needed -lgcc_s --pop-state}}}

END

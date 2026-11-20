unpack $src
# The processor, as Botan names it (the element says x86_64, for the one
# architecture it is built for).
case $triplet in
    aarch64-*) cpu=arm64 ;;
    x86_64-*) cpu=x86_64 ;;
    *) echo "botan.sh: no name of Botan's for the processor of $triplet" >&2; exit 1 ;;
esac
# Botan configures itself with a Python script of its own.
# --disable-shared-library: only the static library, which is linked into
#   the programs that use it (as the element).
# --build-targets=static: and not Botan's own command and tests, which the
#   element builds and nothing uses; the command would be a program of
#   this package, and need the C++ library to run.
python3 configure.py --prefix=/usr --libdir=lib/$triplet \
    --cc=gcc --os=linux --cpu=$cpu --build-targets=static \
    --disable-shared-library --without-documentation --no-install-python-module
make
make DESTDIR=$out install

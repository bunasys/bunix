unpack $src

# The kernel's headers go where glibc's own will: a compiler is then told
# of one include directory.
mkdir -p $out
cp -r $linux_headers/include $out/
# everything in the store is read-only, and the copy came out the same
chmod -R u+w $out/include

mkdir build
cd build
echo "rootsbindir=$out/bin" > configparms

# GNU's name of the processor, for the triplets below
case $system in
    aarch64-linux) cpu=aarch64 ;;
    x86_64-linux) cpu=x86_64 ;;
    *) echo "glibc.sh: GNU's name for $system is not known" >&2; exit 1 ;;
esac

# --host differs from --build in name only.  It makes configure treat this
# as a cross build and not run the programs it compiles: the seed's gcc
# gives them a loader that does not exist (stage1.nix), and glibc cannot be
# built with other link flags than its own.
# --enable-kernel: as in project.conf (glibc-min-kernel)
../configure \
    --prefix=$out \
    --host=$cpu-bunix-linux-gnu --build=$cpu-unknown-linux-gnu \
    --with-headers=$out/include --enable-kernel=5.4 \
    --disable-nscd --disable-werror
make
make install

# On x86_64, ldd is written to look for the loader in lib64 whatever the
# prefix; it is in lib.
if [ $system = x86_64-linux ]; then
    sed -i "s|$out/lib64/|$out/lib/|" $out/bin/ldd
fi

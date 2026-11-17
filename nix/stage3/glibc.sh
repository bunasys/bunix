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

# --enable-kernel: as in project.conf (glibc-min-kernel)
../configure \
    --prefix=$out \
    --with-headers=$out/include --enable-kernel=5.4 \
    --enable-stack-protector=strong \
    --disable-nscd --disable-werror
make
make install

# On x86_64, ldd is written to look for the loader in lib64 whatever the
# prefix; it is in lib.
if [ $system = x86_64-linux ]; then
    sed -i "s|$out/lib64/|$out/lib/|" $out/bin/ldd
fi

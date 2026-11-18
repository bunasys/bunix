unpack $src

# The kernel's headers go where glibc's own will: a compiler is then told
# of one include directory.
mkdir -p $out
cp -r $linux_headers/include $out/
# everything in the store is read-only, and the copy came out the same
chmod -R u+w $out/include

# glibc reads the system's configuration from /etc (--sysconfdir below):
# the time zone in /etc/localtime, as passwd and resolv.conf already are.
# Two files there are not configuration but lists of libraries to load,
# written for the system's own glibc: ld.so.cache and ld.so.preload.  A
# program from the store that read them would load whatever libraries the
# system it happens to run on has.  For these two, the loader is pointed
# into glibc's own path, where neither exists.
sed -i "s|SYSCONFDIR \"/ld.so.cache\"|\"$out/etc/ld.so.cache\"|" sysdeps/generic/dl-cache.h
sed -i "s|\"/etc/ld.so.preload\"|\"$out/etc/ld.so.preload\"|" elf/rtld.c
# a sed that matches nothing succeeds: make sure both are there now
grep -q "\"$out/etc/ld.so.cache\"" sysdeps/generic/dl-cache.h
grep -q "\"$out/etc/ld.so.preload\"" elf/rtld.c

mkdir build
cd build
echo "rootsbindir=$out/bin" > configparms

# --enable-kernel: as in project.conf (glibc-min-kernel)
../configure \
    --prefix=$out --sysconfdir=/etc \
    --with-headers=$out/include --enable-kernel=5.4 \
    --enable-stack-protector=strong \
    --disable-nscd --disable-werror
make
# glibc is built to read /etc, and cannot install into it: the few files it
# puts there go into its own path.  Among them is the cache that ldconfig
# writes when glibc is installed, which nothing is to read.
make install sysconfdir=$out/etc
rm -f $out/etc/ld.so.cache

# On x86_64, ldd is written to look for the loader in lib64 whatever the
# prefix; it is in lib.
if [ $system = x86_64-linux ]; then
    sed -i "s|$out/lib64/|$out/lib/|" $out/bin/ldd
fi

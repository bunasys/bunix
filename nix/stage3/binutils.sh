unpack $src
mkdir build
cd build

# stage 2 has no makeinfo; the tarball ships its manuals already built
export MAKEINFO=true

# ld expects glibc's loader in /lib, as gcc does (gcc.sh).  gcc tells ld
# where it is; this is for a build that calls ld itself.
# Each architecture's file in ld/emulparams may name the loader; aarch64's
# does, x86_64's leaves it to a default elsewhere and is given one here.
case $system in
    aarch64-linux)
        emulation=../ld/emulparams/aarch64linux.sh
        sed -i "s|/lib/ld-linux|$glibc/lib/ld-linux|" $emulation
        ;;
    x86_64-linux)
        emulation=../ld/emulparams/elf_x86_64.sh
        echo "ELF_INTERPRETER_NAME=\\\"$glibc/lib/ld-linux-x86-64.so.2\\\"" >> $emulation
        ;;
    *) echo "binutils.sh: ld's emulation for $system is not known" >&2; exit 1 ;;
esac
# a sed that matches nothing succeeds: make sure the path is there now
grep -q "$glibc/lib/ld-linux" $emulation

# Compiled by stage 1's gcc, for this stage's glibc (see gcc.sh).
loader=$(echo $glibc/lib/ld-linux-*.so.*)
for_this_glibc="-B$glibc/lib -Wl,--dynamic-linker=$loader"

# --with-lib-path: where ld looks for libraries by default
# --enable-plugins: gcc's link-time optimisation is a plugin of ld's
# --disable-shared: libbfd inside each program, not a library to be found
../configure \
    CC="gcc $for_this_glibc" CXX="g++ $for_this_glibc" \
    --prefix=$out --with-lib-path=$glibc/lib \
    --disable-nls --disable-shared --enable-plugins \
    --enable-gprofng=no --disable-werror \
    --enable-64-bit-bfd --enable-new-dtags --enable-default-hash-style=gnu \
    --enable-deterministic-archives
make
make install

unpack $src
# Lua's own build makes only a static library and the two programs, and
# writes no pkg-config file: made a shared library here from the same
# objects, without the programs, with the file WirePlumber looks for
# (lua5.5.pc, the name Debian and Arch give it).
#
# The names carry the version, written out here so a new one stops the
# build until it is changed.
version=5.5
if ! grep -q "^#define LUA_VERSION_MINOR_N[[:space:]]*${version#5.}\$" src/lua.h; then
    echo "lua.sh: this source is not Lua $version, which the library's names below say" >&2
    exit 1
fi
# SYSCFLAGS: what `make linux` would set, and the liblua.a target alone
# does not -- POSIX calls (io.popen, mkstemp, the reentrant time
# functions) and the loading of C modules.  Without it Lua is plain ANSI
# C, and says "dynamic libraries not enabled".
make -C src -j$jobs liblua.a SYSCFLAGS="-DLUA_USE_LINUX" MYCFLAGS="$CFLAGS -fPIC" MYLDFLAGS="$LDFLAGS"
library=liblua$version.so.$version
objects=$(ls src/*.o | grep -v -x -E 'src/lua\.o|src/luac\.o')
gcc -shared $LDFLAGS -Wl,-soname,$library -o $library $objects -lm
if grep -q "dynamic libraries not enabled" $library; then
    echo "lua.sh: Lua was built without what Linux has (LUA_USE_LINUX)" >&2
    exit 1
fi

libraries=$out/usr/lib/$triplet
install -D -m 755 $library $libraries/$library
ln -s $library $libraries/liblua$version.so
install -D -m 644 -t $out/usr/include/lua$version src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp
mkdir -p $libraries/pkgconfig
printf '%s\n' 'prefix=/usr' "libdir=/usr/lib/$triplet" "includedir=/usr/include/lua$version" '' \
    'Name: Lua' 'Description: An extensible extension language' "Version: $lua_version" \
    "Libs: -L\${libdir} -llua$version" 'Libs.private: -lm' 'Cflags: -I${includedir}' \
    > $libraries/pkgconfig/lua$version.pc

unpack $src

# What Neovim builds itself of (base.nix), from its own build of them
# (cmake.deps), which downloads each from the URL in cmake.deps/deps.txt
# and checks it against the SHA-256 there.  A build here has no network:
# each URL is made the source fetched for it, a file CMake takes as one;
# the SHA-256 is still checked, against Neovim's own list.
deps=cmake.deps/deps.txt
for dependency in LIBUV LUAJIT LUV LPEG LUA_COMPAT53 UTF8PROC UNIBILIUM TREESITTER \
                  TREESITTER_C TREESITTER_LUA TREESITTER_VIM TREESITTER_VIMDOC \
                  TREESITTER_QUERY TREESITTER_MARKDOWN; do
    variable=$(echo $dependency | tr A-Z a-z)_source
    sed -i "s|^${dependency}_URL .*|${dependency}_URL ${!variable}|" $deps
    grep -q -x "${dependency}_URL ${!variable}" $deps || {
        echo "neovim.sh: $deps names no ${dependency}_URL" >&2
        exit 1
    }
done

# The dependencies, as Neovim builds them, static, into .deps.  Not
# gettext and libiconv, which glibc has; not wasmtime (a Rust build, for
# tree-sitter parsers in WebAssembly, which Neovim does without).
cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=Release \
    -D USE_BUNDLED=ON -D USE_BUNDLED_GETTEXT=OFF -D USE_BUNDLED_LIBICONV=OFF \
    -D USE_BUNDLED_WASMTIME=OFF
cmake --build .deps -j $jobs

# Neovim itself, with UAPI.9's directories
cmake -S . -B build -G Ninja -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr -D CMAKE_INSTALL_LIBDIR=lib/$triplet
cmake --build build -j $jobs
DESTDIR=$out cmake --install build

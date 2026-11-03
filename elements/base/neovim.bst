kind: manual
description: |
  Neovim -- the editor (vi and vim point at it in the system image)

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/cmake.bst
- base/ninja.bst

# Neovim builds its bundled dependencies (LuaJIT, libuv, luv, lpeg,
# tree-sitter and its parsers, utf8proc, unibilium) first, in cmake.deps.
# Normally that downloads them; here they are sources, staged where its
# download step looks, and with the checksums from its cmake.deps/deps.txt --
# which it verifies again before skipping the download.  Linked statically
# into nvim, so nothing of them is installed.
sources:
- kind: tar
  url: github:neovim/neovim/archive/refs/tags/v0.12.6.tar.gz
  ref: 8629fdc5eb951daf89a76f68cad12f2f1e03fab0d539150ba3fe6d177d254b7f
- kind: remote
  url: github:libuv/libuv/archive/v1.52.1.tar.gz
  directory: .deps/build/downloads/libuv
  filename: v1.52.1.tar.gz
  ref: 478baf2599bfbc882c355288c9cb6f92e0e7dda435fa04031fa5b607cf3f414c
- kind: remote
  url: github:luajit/luajit/archive/fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac.tar.gz
  directory: .deps/build/downloads/luajit
  filename: fbb36bb6bfa88716a47c58bcf9ce9f2ef752abac.tar.gz
  ref: e60cd2f3057aa39d33d1c895a20087ab54494d9a1ca45aa488ff0378af42df48
- kind: remote
  url: github:neovim/unibilium/archive/v2.1.2.tar.gz
  directory: .deps/build/downloads/unibilium
  filename: v2.1.2.tar.gz
  ref: 370ecb07fbbc20d91d1b350c55f1c806b06bf86797e164081ccc977fc9b3af7a
- kind: remote
  url: github:luvit/luv/archive/1.52.1-0.tar.gz
  directory: .deps/build/downloads/luv
  filename: 1.52.1-0.tar.gz
  ref: e8b8774b31d24be4fcf2b021b90599ecccc8e476c61efcc59c3c10cab813a885
- kind: remote
  url: github:lunarmodules/lua-compat-5.3/archive/v0.13.tar.gz
  directory: .deps/build/downloads/lua_compat53
  filename: v0.13.tar.gz
  ref: f5dc30e7b1fda856ee4d392be457642c1f0c259264a9b9bfbcb680302ce88fc2
- kind: remote
  url: github:neovim/deps/raw/d495ee6f79e7962a53ad79670cb92488abe0b9b4/opt/lpeg-1.1.0.tar.gz
  directory: .deps/build/downloads/lpeg
  filename: lpeg-1.1.0.tar.gz
  ref: 4b155d67d2246c1ffa7ad7bc466c1ea899bbc40fef0257cc9c03cecbaed4352a
- kind: remote
  url: github:juliastrings/utf8proc/archive/v2.11.3.tar.gz
  directory: .deps/build/downloads/utf8proc
  filename: v2.11.3.tar.gz
  ref: abfed50b6d4da51345713661370290f4f4747263ee73dc90356299dfc7990c78
- kind: remote
  url: github:tree-sitter/tree-sitter/archive/v0.26.13.tar.gz
  directory: .deps/build/downloads/treesitter
  filename: v0.26.13.tar.gz
  ref: ece24c3c5e2a76384075e830c7139b59fce8fb01e4ef8436fab08bbe10444c89
- kind: remote
  url: github:tree-sitter/tree-sitter-c/archive/v0.24.1.tar.gz
  directory: .deps/build/downloads/treesitter_c
  filename: v0.24.1.tar.gz
  ref: 25dd4bb3dec770769a407e0fc803f424ce02c494a56ce95fedc525316dcf9b48
- kind: remote
  url: github:tree-sitter-grammars/tree-sitter-lua/archive/v0.5.0.tar.gz
  directory: .deps/build/downloads/treesitter_lua
  filename: v0.5.0.tar.gz
  ref: cf01b93f4b61b96a6d27942cf28eeda4cbce7d503c3bef773a8930b3d778a2d9
- kind: remote
  url: github:tree-sitter-grammars/tree-sitter-vim/archive/v0.8.1.tar.gz
  directory: .deps/build/downloads/treesitter_vim
  filename: v0.8.1.tar.gz
  ref: 93cafb9a0269420362454ace725a118ff1c3e08dcdfdc228aa86334b54d53c2a
- kind: remote
  url: github:neovim/tree-sitter-vimdoc/archive/v4.1.0.tar.gz
  directory: .deps/build/downloads/treesitter_vimdoc
  filename: v4.1.0.tar.gz
  ref: 020e8f117f648c8697fca967995c342e92dbd81dab137a115cc7555207fbc84f
- kind: remote
  url: github:tree-sitter-grammars/tree-sitter-query/archive/v0.8.0.tar.gz
  directory: .deps/build/downloads/treesitter_query
  filename: v0.8.0.tar.gz
  ref: c2b23b9a54cffcc999ded4a5d3949daf338bebb7945dece229f832332e6e6a7d
- kind: remote
  url: github:tree-sitter-grammars/tree-sitter-markdown/archive/v0.5.3.tar.gz
  directory: .deps/build/downloads/treesitter_markdown
  filename: v0.5.3.tar.gz
  ref: df845b1ab7c7c163ec57d7fa17170c92b04be199bddab02523636efec5224ab6

config:
  configure-commands:
  - cmake -S cmake.deps -B .deps -G Ninja -DCMAKE_BUILD_TYPE=Release
  - cmake --build .deps
  # cmake's default libdir is lib64, where nvim would put its tree-sitter
  # parsers; UAPI.9 has the multiarch $libdir instead
  - |
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=%{prefix} -DCMAKE_INSTALL_LIBDIR=%{lib} \
      -DDEPS_PREFIX=$PWD/.deps/usr
  build-commands:
  - cmake --build build
  install-commands:
  - DESTDIR=%{install-root} cmake --install build

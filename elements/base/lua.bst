kind: manual
description: |
  Lua 5.5 -- WirePlumber's scripting.  Upstream builds only a static
  library and has no pkg-config file: this builds liblua5.5.so from the same
  objects and writes lua5.5.pc (the name Debian and Arch use).  Without
  the lua and luac programs.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://www.lua.org/ftp/lua-5.5.1.tar.gz
  ref: 1c4b4068d67061f2a2231ad2b5422e77acea1487ea9890f6320af614f4373dce

config:
  build-commands:
  - make -C src liblua.a PLAT=linux MYCFLAGS="%{cflags} -fPIC" MYLDFLAGS="%{ldflags}"
  - |
    cd src
    objects=$(ls *.o | grep -vxE 'lua\.o|luac\.o')
    gcc -shared %{ldflags} -Wl,-soname,liblua5.5.so.5.5 -o liblua5.5.so.5.5 $objects -lm

  install-commands:
  - |
    install -D -m 0755 src/liblua5.5.so.5.5 %{install-root}%{libdir}/liblua5.5.so.5.5
    ln -s liblua5.5.so.5.5 %{install-root}%{libdir}/liblua5.5.so
    mkdir -p %{install-root}%{includedir}/lua5.5
    install -m 0644 src/lua.h src/luaconf.h src/lualib.h src/lauxlib.h src/lua.hpp \
      %{install-root}%{includedir}/lua5.5/
  - |
    mkdir -p %{install-root}%{libdir}/pkgconfig
    cat > %{install-root}%{libdir}/pkgconfig/lua5.5.pc <<'PC'
    prefix=/usr
    libdir=%{libdir}
    includedir=%{includedir}/lua5.5

    Name: Lua
    Description: An extensible extension language
    Version: 5.5.1
    Libs: -L${libdir} -llua5.5
    Libs.private: -lm
    Cflags: -I${includedir}
    PC

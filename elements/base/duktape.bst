kind: manual
description: |
  Duktape -- a small JavaScript interpreter, which polkit runs its rules
  (/usr/share/polkit-1/rules.d) in.  Its single-file source built as a
  shared library, with the pkg-config file polkit looks for.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: https://duktape.org/duktape-2.7.0.tar.xz
  ref: 90f8d2fa8b5567c6899830ddef2c03f3c27960b11aca222fa17aa7ac613c2890

config:
  build-commands:
  - |
    gcc %{cflags} -fPIC -shared -Wl,-soname,libduktape.so.207 \
      -o libduktape.so.207.20700 src/duktape.c -lm
  install-commands:
  - |
    install -D -m 0755 libduktape.so.207.20700 %{install-root}%{libdir}/libduktape.so.207.20700
    ln -s libduktape.so.207.20700 %{install-root}%{libdir}/libduktape.so.207
    ln -s libduktape.so.207 %{install-root}%{libdir}/libduktape.so
    install -D -m 0644 -t %{install-root}%{includedir} src/duktape.h src/duk_config.h
    mkdir -p %{install-root}%{libdir}/pkgconfig
    printf '%s\n' 'prefix=/usr' 'libdir=%{libdir}' 'includedir=%{includedir}' '' \
      'Name: duktape' 'Description: Embeddable JavaScript engine' 'Version: 2.7.0' \
      'Libs: -L${libdir} -lduktape' 'Libs.private: -lm' 'Cflags: -I${includedir}' \
      > %{install-root}%{libdir}/pkgconfig/duktape.pc

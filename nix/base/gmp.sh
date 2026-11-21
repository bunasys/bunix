unpack $src
# -std=gnu17: its configure tests are C that gcc's newer default (C23)
# refuses
CFLAGS="$CFLAGS -std=gnu17" ./configure $configure_for_usr --disable-static
make
make DESTDIR=$out install

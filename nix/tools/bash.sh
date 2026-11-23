unpack $src
# --without-bash-malloc: bash's own malloc is known to crash where glibc's
#   does not.
# --with-installed-readline=no: its own copy of readline, built in.
# --with-curses: that readline asks ncurses about the terminal.  Left to
#   itself it uses a copy of termcap, which reads /etc/termcap, a file no
#   system has any more, and the line editor cannot clear or redraw.
./configure $configure_for_usr --without-bash-malloc --with-installed-readline=no \
    --with-curses --disable-nls
make
make DESTDIR=$out install
ln -s bash $out/usr/bin/sh

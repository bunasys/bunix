unpack $src
# --without-bash-malloc: bash's own malloc is known to crash where glibc's
#   does not.
# --with-installed-readline=no: its own copy of readline, built in.
./configure $configure_for_usr --without-bash-malloc --with-installed-readline=no --disable-nls
make
make DESTDIR=$out install
ln -s bash $out/usr/bin/sh

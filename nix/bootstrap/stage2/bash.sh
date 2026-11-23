unpack $src
# --without-bash-malloc: bash's own malloc is known to crash where glibc's
# does not.
# INSTALL: the file bash installs for building its loadable commands
# records it; by name, not the path configure would find (stage2.nix).
./configure --prefix=$out --without-bash-malloc INSTALL="install -c"
make
make install
ln -s bash $out/bin/sh

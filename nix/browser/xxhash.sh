unpack $src
# No configure step: make with the directories set, for the install too.
# The shared library is what ccache links; xxhsum comes with it.
directories="prefix=/usr libdir=/usr/lib/$triplet"
make $directories
make $directories DESTDIR=$out install
# the static library: nothing here links it
rm $out/usr/lib/$triplet/libxxhash.a

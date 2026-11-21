unpack $src
# One of its rules is for scripts run by a program in a Nix store, and
# names the store to say so.  A system package may not name it
# (system-package.sh), and cannot tell this from a path it would go and
# look for: the rule goes, and such a script is "a script" to file.
# (the rule, and the lines that belong to it: up to the empty line after)
sed -i '/^0\tstring\t#!\/nix\/store\/$/,/^$/d' magic/Magdir/commands
if grep -q /nix/store magic/Magdir/*; then
    echo "file.sh: its rules still name the store" >&2
    exit 1
fi
# the compression libraries: -z looks inside compressed files
./configure $configure_for_usr --disable-static --disable-libseccomp \
    --enable-zlib --enable-bzlib --enable-xzlib --enable-zstdlib --disable-lzlib
make
make DESTDIR=$out install

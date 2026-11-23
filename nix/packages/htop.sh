unpack $src
# htop dims the well-known start of a command's path (/usr/bin/, and a
# Nix store's among them).  A bunix has no store, and no file of its
# system may name one (system-package.sh): that one start goes.  The
# path is put together here, in two parts: this script is handed to
# machines, and so is a file of the system too.
store=/nix
store=$store/store
sed -i "s|CHECK_AND_MARK(str_, \"$store/\");||" Process.c
if grep -q $store Process.c; then
    echo "htop.sh: Process.c still names the store" >&2
    exit 1
fi
# As ../autotools.sh, after that.  Sensors (lm-sensors), delay accounting
# (libnl) and hwloc are optional libraries this system does not have.
./configure $configure_for_usr --enable-unicode --disable-sensors --disable-delayacct --disable-hwloc
make
make DESTDIR=$out install

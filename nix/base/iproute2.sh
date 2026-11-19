unpack $src

# The parts a system needs: ip, bridge, and ss and others of misc/.  Not
# tc, the traffic shaper: nothing here uses it.
# NETNS_RUN_DIR: `ip netns` keeps its files there; /run, not the old
#   /var/run that is iproute2's default.  The element lacks this.
iproute2_make() {
    make SUBDIRS="lib ip bridge misc" PREFIX=/usr SBINDIR=/usr/bin \
        CONF_USR_DIR=/usr/share/iproute2 NETNS_RUN_DIR=/run/netns \
        CCOPTS="$CFLAGS" "$@"
}

# iproute2's configure is its own, not autoconf's.
./configure --prefix=/usr --libdir=/usr/lib/$triplet --libbpf_force off
iproute2_make
iproute2_make DESTDIR=$out install

# A python script that prints `ip route` as a table; it would make
# iproute2 need python to run.  The element keeps it.
rm $out/usr/bin/routel

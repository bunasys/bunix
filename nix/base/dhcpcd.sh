unpack $src
# dhcpcd's configure is its own, not autoconf's.
# --privsepuser: the part of dhcpcd that reads what the network sends runs
#   as this user, with no rights, inside that user's home, which is to be
#   an empty directory; the image has the account.
./configure --prefix=/usr --sbindir=/usr/bin --libdir=/usr/lib/$triplet \
    --libexecdir=/usr/lib/dhcpcd --sysconfdir=/etc \
    --dbdir=/var/lib/dhcpcd --runstatedir=/run --privsepuser=dhcpcd
make
make DESTDIR=$out install
# /var is the running system's, not a package's
rm -rf $out/var
install -d $out/usr/share/empty.dhcpcd

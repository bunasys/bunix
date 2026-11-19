unpack $src
# dhcpcd's configure is its own, not autoconf's.
# --privsepuser: the part of dhcpcd that reads what the network sends runs
#   as this user, with no rights, inside that user's home, which is to be
#   an empty directory.
./configure --prefix=/usr --sbindir=/usr/bin --libdir=/usr/lib/$triplet \
    --libexecdir=/usr/lib/dhcpcd --sysconfdir=/etc \
    --dbdir=/var/lib/dhcpcd --runstatedir=/run --privsepuser=dhcpcd
make
make DESTDIR=$out install
# /var is the running system's, not a package's
rm -rf $out/var
install -d $out/usr/share/empty.dhcpcd
# the account of --privsepuser, for whatever puts an image together
install -d $out/usr/lib/sysusers.d
echo 'u dhcpcd 75 "dhcpcd privilege separation" /usr/share/empty.dhcpcd' > $out/usr/lib/sysusers.d/dhcpcd.conf

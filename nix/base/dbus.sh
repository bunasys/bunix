unpack $src
# Built with meson, with more steps than ../meson.sh has; the arguments
# for UAPI.9's places are as there, but for --libexecdir (below).  After them, the element's
# arguments, with systemd's parts off.
# --libexecdir: its helper that starts services gets a directory of its
#   own.  It is installed without set-user-id, which a build cannot give:
#   the bus starts no service by itself here, and nothing asks it to yet.
# runtime_dir, system_socket: /run, not the old /var/run.
# dbus_user: the bus gives up root's rights for this account.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib/dbus-1.0 --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    -Dsystemd=disabled -Druntime_dir=/run -Dsystem_socket=/run/dbus/system_bus_socket \
    -Ddbus_user=messagebus \
    -Dmessage_bus=true -Dtools=true -Duser_session=false \
    -Dselinux=disabled -Dapparmor=disabled -Dlibaudit=disabled \
    -Dx11_autolaunch=disabled -Dmodular_tests=disabled -Dinstalled_tests=false \
    -Ddoxygen_docs=disabled -Dducktype_docs=disabled -Dxml_docs=disabled \
    -Dqt_help=disabled
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
# /var and /run are the running system's, not a package's
rm -rf $out/var $out/run

# the account of dbus_user, for whatever puts an image together
install -d $out/usr/lib/sysusers.d
echo 'u messagebus 81 "D-Bus system bus" /run/dbus' > $out/usr/lib/sysusers.d/dbus.conf

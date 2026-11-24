# The session bus's two user units, from dbus's own templates: the base's
# dbus is built without them (base/dbus.sh, -Duser_session=false).  The
# socket comes up with a person's session; the bus starts on its first
# connection.
unpack $src
units=$out/usr/lib/systemd/user
mkdir -p $units/sockets.target.wants
for unit in dbus.service dbus.socket; do
    sed -e 's|@EXPANDED_BINDIR@|/usr/bin|g' -e 's|@SYSTEMCTL@|/usr/bin/systemctl|g' \
        bus/systemd-user/$unit.in > $units/$unit
done
ln -s ../dbus.socket $units/sockets.target.wants/dbus.socket
if grep -n '@' $units/dbus.service $units/dbus.socket; then
    echo "dbus-user-session.sh: a template left unfilled" >&2
    exit 1
fi

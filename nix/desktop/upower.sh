unpack $src

# ../meson.sh's lines.  No manual pages or reference (xsltproc and
# gtk-doc, which bunix does not have), no iPhones' batteries
# (libimobiledevice), and no tests installed.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dman=false -Dgtk-doc=false -Dintrospection=disabled -Didevice=disabled \
    -Dpolkit=enabled -Dinstalled_tests=false -Dzshcompletiondir=no \
    -Dudevrulesdir=/usr/lib/udev/rules.d -Dudevhwdbdir=/usr/lib/udev/hwdb.d \
    -Dsystemdsystemunitdir=/usr/lib/systemd/system
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
# /var is the running system's: the unit makes the daemon's directory
# (StateDirectory=upower)
rm -rf $out/var

# Its settings (when the battery is low, and what is done when it is
# empty) are in /etc/UPower, which an extension cannot bring: it lays
# /usr over the system, and nothing else.  Without the file every
# setting reads as nought.  So they are in /usr, and the daemon is told
# where (UPOWER_CONF_FILE_NAME).  It reads the UPower.conf.d beside that
# file too, which in /usr a machine cannot add to: its own settings go in
# a drop-in for the unit that names a file in /etc instead, say
# /etc/UPower/UPower.conf, and then /etc/UPower/UPower.conf.d is read.
settings=$out/usr/share/upower
mkdir -p $settings
mv $out/etc/UPower/UPower.conf $settings/UPower.conf
rm -r $out/etc
# When the battery is all but empty: power off.  Its own choice, Auto,
# is logind's Sleep(), which is a suspend where there is no hibernation,
# as on a Mac: the battery then runs out while it sleeps, and the
# machine is cut off without a clean shutdown.
sed -i 's/^CriticalPowerAction=Auto$/CriticalPowerAction=PowerOff/' $settings/UPower.conf
grep -q -x 'CriticalPowerAction=PowerOff' $settings/UPower.conf || {
    echo "upower.sh: UPower.conf's CriticalPowerAction is not Auto any more" >&2
    exit 1
}
install -D -m 644 /dev/stdin $out/usr/lib/systemd/system/upower.service.d/bunix.conf <<'UNIT'
[Service]
Environment=UPOWER_CONF_FILE_NAME=/usr/share/upower/UPower.conf
UNIT

# Its hardware database (batteries known to report wrongly, which
# batteries' charge can be limited, and UPSes), which udev reads only
# from /usr's compiled hwdb.bin, made with the system: an extension's
# would never be read.  Its rules, which look there, then find nothing,
# and leave the device as the kernel has it: no charge limit offered,
# and a UPS on USB not known as one.
rm -r $out/usr/lib/udev/hwdb.d

# Started at boot, upheld by multi-user.target (docs/desktop.md, "Units
# in an extension"), as the extension's other services are, and not on
# DMS's first D-Bus call: the battery's history it keeps then covers the
# time before anyone logged in, and the low-battery action is there for
# the login screen too.
install -D -m 644 /dev/stdin $out/usr/lib/systemd/system/multi-user.target.d/upower.conf <<'UNIT'
[Unit]
Upholds=upower.service
UNIT

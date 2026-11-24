unpack $src
# Its version comes from the source directory's name, or from git, which
# a build here has neither of: said outright
printf '#!/bin/sh\necho %s\n' "$release" > generate-version.sh
# No tests: they need mocklibc, which no longer compiles (GCC 16), and
# nothing turns them off but leaving them out
sed -i "/^subdir('tests')$/d" meson.build
if grep -q "subdir('tests')" meson.build; then
    echo "accountsservice.sh: its tests are still in its build" >&2
    exit 1
fi

# ../meson.sh's lines
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dintrospection=false -Dvapi=false -Dadmin_group=wheel \
    -Dsystemdsystemunitdir=/usr/lib/systemd/system
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install
# /var is the running system's: the daemon makes its directories
rm -rf $out/var

# Its sandbox names paths that must all be there, or the service does
# not start (226/NAMESPACE): bunix has no /var/log/wtmp (systemd is built
# without utmp), the interfaces directory is never installed, and logind's
# seats are there only once logind runs.  They are made optional (`-`),
# and it starts after logind.
unit=$out/usr/lib/systemd/system/accounts-daemon.service
sed -i -e 's#^\(  \)\(/var/log/wtmp\|/usr/share/accountsservice/interfaces/\|/run/systemd/seats/\)#\1-\2#' \
       -e 's#^After=nss-user-lookup.target$#After=nss-user-lookup.target systemd-logind.service#' $unit
grep -q '^  -/var/log/wtmp ' $unit
grep -q '^  -/usr/share/accountsservice/interfaces/ ' $unit
grep -q '^  -/run/systemd/seats/$' $unit
grep -q '^After=nss-user-lookup.target systemd-logind.service$' $unit

# Started at boot, upheld by multi-user.target (docs/desktop.md, "Units
# in an extension"), and not on its first D-Bus call: its list of users is
# ready when the login screen draws
install -D -m 644 /dev/stdin $out/usr/lib/systemd/system/multi-user.target.d/accountsservice.conf <<'UNIT'
[Unit]
Upholds=accounts-daemon.service
UNIT

unpack $src
# Built as desktop/dms.sh builds DMS.  Its widget library, a git
# submodule, which the release's archive has not.  No patch: only its
# tests name the store, and they are not part of the program.
unpack $qml_common dux-qml-common

# Its Go modules as a module proxy lays them out, which Go reads offline;
# each of $go_modules is <where in the proxy>=<file> (desktop.nix,
# goModules)
for module in $go_modules; do
    install -D -m 644 ${module#*=} /build/goproxy/${module%%=*}
done
export GOPROXY=file:///build/goproxy GOMODCACHE=/build/gomodcache GOCACHE=/build/gocache
# go.sum is the check: there is no checksum database to ask offline
export GOSUMDB=off

# a fixed version, commit and build time, and -trimpath, as for DMS
make -C core build VERSION=$release COMMIT=v$release BUILD_TIME=v$release GOFLAGS=-trimpath
make install-bin PREFIX=/usr DESTDIR=$out
go version -m $out/usr/bin/dms-greeter | grep -q -- '-tags=withshell'
go version -m $out/usr/bin/dms-greeter | grep -q -- '-trimpath=true'

# greetd's configuration (desktop/greetd.sh): on tty1, dms-greeter as the
# "greeter" user, in niri; what it says goes to the journal, not onto the
# console.  A login starts the session the person picks from
# /usr/share/wayland-sessions (niri's).
greetd=$out/usr/share/greetd
install -d $greetd
cat > $greetd/config.toml <<'TOML'
[terminal]
vt = 1

[default_session]
command = "systemd-cat --identifier=dms-greeter dms-greeter --command niri"
user = "greeter"
TOML

# US and Arabic keyboards on the login screen, Alt+Shift switches, as in
# the session (desktop/dms.sh): dms-greeter adds this to its own niri
# configuration
cat > $greetd/niri_overrides.kdl <<'KDL'
input {
    keyboard {
        xkb {
            layout "us,ara"
            options "grp:alt_shift_toggle"
        }
    }
}
KDL

# Its cache, /var/cache/dms-greeter, where dms-greeter keeps the theme and
# the session last chosen: made by systemd-tmpfiles, which will not follow
# a symlink the greeter user has put in its own directory (root's chown or
# install there would follow it, to /etc say).  Made before greetd starts
# the greeter, and after greetd has made the user: the boot's tmpfiles run
# before the extension is merged.  `-`: the greeter starts without it.
install -D -m 644 /dev/stdin $out/usr/lib/tmpfiles.d/dms-greeter.conf <<'CONF'
d /var/cache/dms-greeter 2770 greeter greeter -
CONF
install -D -m 644 /dev/stdin $out/usr/lib/systemd/system/greetd.service.d/dms-greeter.conf <<'UNIT'
[Service]
ExecStartPre=-/usr/bin/systemd-tmpfiles --create /usr/lib/tmpfiles.d/dms-greeter.conf
UNIT

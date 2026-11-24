unpack $src
# its widget library, a git submodule, where the release's archive has an
# empty directory for it
unpack $qml_common dux-qml-common
# The patch (files/dms/): the text "/nix/store", which DMS looks for in
# programs' paths, is put together when it runs, so that the package
# check, which refuses a package that names the store, takes it.  The
# interface's tests name the store too, and are not run here: removed.
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done
rm -r quickshell/tests

# The Go modules as a module proxy lays them out, which Go reads offline;
# Go checks each against go.sum.  Each of $go_modules is
# <where in the proxy>=<file> (desktop.nix, goModules).
for module in $go_modules; do
    install -D -m 644 ${module#*=} /build/goproxy/${module%%=*}
done
export GOPROXY=file:///build/goproxy GOMODCACHE=/build/gomodcache GOCACHE=/build/gocache
# go.sum is the check: there is no checksum database to ask offline
export GOSUMDB=off

# The interface's revision key, .dankrev, is a hash of the interface's
# files, which the Makefile writes while it lists them: whether it hashes
# .dankrev itself depended on timing, so the same source gave different
# programs.  It is left out of the list.
sed -i 's/find \. -type f -print0 | LC_ALL=C sort -z/find . -type f ! -name .dankrev -print0 | LC_ALL=C sort -z/' core/Makefile
grep -q 'find . -type f ! -name .dankrev -print0' core/Makefile

# The version and commit, which the Makefile asks git for (the archive
# has no .git), and a fixed build time: the same source, the same program.
# GOFLAGS=-trimpath: without the paths it was built from, its Go's among
# them, which are in the store.  On make's command line: the Makefile has
# a GOFLAGS of its own, which it would mix an environment's into.
make -C core build VERSION=$release COMMIT=v$release BUILD_TIME=v$release GOFLAGS=-trimpath

# Not `make install`: it also writes a systemd unit into the home of
# whoever builds, and refreshes the icon and MIME caches
make install-bin install-completions PREFIX=/usr DESTDIR=$out
install -D -m 644 assets/dev.duxlabs.shell.svg $out/usr/share/icons/hicolor/scalable/apps/dev.duxlabs.shell.svg
for entry in dms-open dev.duxlabs.shell dev.duxlabs.shell.notepad; do
    install -D -m 644 assets/$entry.desktop $out/usr/share/applications/$entry.desktop
done
# Its interface is inside it (-tags withshell), or it would look for one
# on disk.  Asked of its build information, not of the program: dms
# will not run as root, which a build is.
go version -m $out/usr/bin/dms | grep -q -- '-tags=withshell'
go version -m $out/usr/bin/dms | grep -q -- '-trimpath=true'

# DMS in the niri session, as `dms setup` sets it up, which cannot be
# done here: it asks questions, and for root.
#
# 1. Its niri configuration, in /usr/share/dms/niri: config.kdl and the
#    dms/*.kdl files it includes (keys, layout, colours, alt-tab, input),
#    with Alacritty for a terminal, and US and Arabic keyboards (Alt+Shift
#    switches, as on the login screen)
embedded=core/internal/config/embedded
niri=$out/usr/share/dms/niri
install -D -m 644 $embedded/niri.kdl $niri/config.kdl
for part in binds layout colors alttab input; do
    install -D -m 644 $embedded/niri-$part.kdl $niri/dms/$part.kdl
done
sed -i 's/{{TERMINAL_COMMAND}}/alacritty/g' $niri/config.kdl $niri/dms/binds.kdl
sed -i '/^        xkb {$/a\            layout "us,ara"\n            options "grp:alt_shift_toggle"' $niri/config.kdl
if grep -rq '{{' $niri; then
    echo "dms.sh: a template left unfilled in $niri" >&2
    exit 1
fi
grep -q '^            layout "us,ara"$' $niri/config.kdl

# 2. A new person's ~/.config/niri gets that configuration before niri
#    first starts: niri would otherwise write its own, without DMS's keys.
#    A configuration that is there already is never touched.
units=$out/usr/lib/systemd/user
mkdir -p $units/niri.service.wants
cat > $units/dms-niri-config.service <<'UNIT'
[Unit]
Description=Copy DMS's niri configuration to a new user
ConditionPathExists=!%h/.config/niri/config.kdl
Before=niri.service

[Service]
Type=oneshot
ExecStart=/usr/bin/mkdir -p %h/.config/niri
ExecStart=/usr/bin/cp -r -n /usr/share/dms/niri/. %h/.config/niri/
UNIT
ln -s ../dms-niri-config.service $units/niri.service.wants/dms-niri-config.service

# 3. DMS starts with niri: upstream's unit, wanted by niri.service, as
#    `systemctl --user add-wants niri.service dms` would have it
install -D -m 644 assets/systemd/dms.service $units/dms.service
ln -s ../dms.service $units/niri.service.wants/dms.service

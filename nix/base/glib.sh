unpack $src
# Built with meson, with one more step than ../meson.sh has; the
# arguments for UAPI.9's places are as there.  After them, the element's.
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dlibmount=enabled -Dselinux=disabled -Dsysprof=disabled -Dintrospection=disabled \
    -Dlibelf=disabled -Dnls=disabled -Ddtrace=disabled -Dsystemtap=disabled \
    -Dman-pages=disabled -Ddocumentation=false -Dtests=false -Dglib_debug=disabled
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# GLib's tools for a build that uses it are Python, and not programs of a
# running system: among the programs they would make every system with
# GLib need Python to run (as systemd's ukify, base/systemd.sh).  They are
# kept in a directory of their own, and GLib's pkg-config files, which is
# where a build asks for them, say so.
build_tools=/usr/lib/glib-2.0/build-tools
mkdir -p $out$build_tools
# (gtester-report is moved and not named below: no pkg-config file has it)
for tool in glib-mkenums glib-genmarshal gdbus-codegen gtester-report; do
    mv $out/usr/bin/$tool $out$build_tools/
done
pkgconfig=$out/usr/lib/$triplet/pkgconfig
sed -i "s#=\${bindir}/\(glib-mkenums\|glib-genmarshal\|gdbus-codegen\)\$#=$build_tools/\1#" \
    $pkgconfig/glib-2.0.pc $pkgconfig/gio-2.0.pc
# one for each of mkenums, genmarshal and codegen
tools_named=$(cat $pkgconfig/glib-2.0.pc $pkgconfig/gio-2.0.pc | grep -c "=$build_tools/")
if [ "$tools_named" != 3 ]; then
    echo "glib.sh: GLib's pkg-config files do not name the three tools in $build_tools" >&2
    exit 1
fi
python_programs_left=$(grep -l -r '^#!.*python' $out/usr/bin || true)
if [ -n "$python_programs_left" ]; then
    echo "glib.sh: still among the programs, and Python: $python_programs_left" >&2
    exit 1
fi

unpack $src
# ../meson.sh's lines, with GLib's build tools on PATH: GTK looks for
# gdbus-codegen there, not through pkg-config, and GLib keeps its tools
# out of /usr/bin (base/glib.sh).  Wayland only, nothing printed or
# streamed (as 0.4.0's element).
PATH=/usr/lib/glib-2.0/build-tools:$PATH
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload \
    -Dx11-backend=false -Dwayland-backend=true -Dbroadway-backend=false \
    -Dmedia-gstreamer=disabled -Dprint-cups=disabled \
    -Dprint-cpdb=disabled -Dvulkan=disabled -Dcloudproviders=disabled \
    -Dsysprof=disabled -Dtracker=disabled -Dcolord=disabled \
    -Daccesskit=disabled -Dintrospection=disabled -Ddocumentation=false \
    -Dman-pages=false -Dbuild-demos=false -Dbuild-testsuite=false \
    -Dbuild-examples=false -Dbuild-tests=false
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

# For a system package that meson configures and ninja builds, and that
# needs nothing else: what `kind: meson` is to a .bst element, as
# autotools.sh is for `kind: autotools`.  (base/meson.sh is something
# else: it builds meson itself.)
#
# $meson_arguments is what the package adds (meson-local in a .bst
# element).  It is split at spaces: a package that needs an argument with
# one in it, or another step, has a script of its own with these lines in
# it, as base/dbus.sh is.
#
# The arguments before it put things where UAPI.9 has them.  They are
# here, and again in such a script, and not beside $configure_for_usr in
# system-package.sh: a change there rebuilds every package.
# --wrap-mode=nodownload: a library the package would otherwise fetch for
#   itself is one to declare; without this, meson tries, fails for want
#   of a network, and may go on without it.
unpack $src
meson setup build --prefix=/usr --bindir=bin --sbindir=bin --libdir=lib/$triplet \
    --libexecdir=lib --sysconfdir=/etc --localstatedir=/var --buildtype=release \
    --wrap-mode=nodownload ${meson_arguments:-}
ninja -C build -j$jobs
DESTDIR=$out ninja -C build install

unpack $src
# As base/rust.sh installs Rust's other parts, into the same directory.
bash install.sh --destdir=$out --prefix=/usr/lib/rust --disable-ldconfig

# What the install script wrote to uninstall with; base/rust.sh has the
# same files, of its own parts.
rustlib=$out/usr/lib/rust/lib/rustlib
rm $rustlib/{install.log,uninstall.sh,components,rust-installer-version} $rustlib/manifest-*

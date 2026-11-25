# ../base/rust.sh's way, into a directory of its own: each archive is one
# part of Rust with an install script of its own.
for archive in $src $rust_std $cargo; do
    rm -rf component
    unpack $archive component
    bash component/install.sh --destdir=$out --prefix=/usr/lib/chromium-rust-stage0 --disable-ldconfig
done
rustlib=$out/usr/lib/chromium-rust-stage0/lib/rustlib
rm $rustlib/{install.log,uninstall.sh,components,rust-installer-version} $rustlib/manifest-*
# As published it cannot start (../base/rust.sh), and nothing uses it
rm $rustlib/*/bin/rust-objcopy

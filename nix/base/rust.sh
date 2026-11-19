# Each archive is one part of Rust with an install script of its own.
# --prefix=/usr/lib/rust: rustc looks for its libraries in ../lib from
#   where it is, and they are not libraries of the system's.
for archive in $src $rust_std $cargo $rust_src; do
    rm -rf component
    unpack $archive component
    bash component/install.sh --destdir=$out --prefix=/usr/lib/rust --disable-ldconfig
done

# What the install scripts wrote to uninstall with: lists of files, with
# the path of this build in them.
rustlib=$out/usr/lib/rust/lib/rustlib
rm $rustlib/{install.log,uninstall.sh,components,rust-installer-version} $rustlib/manifest-*

# As published it cannot start: it looks for rustc's LLVM library in two
# directories, neither of which has it.  rustc does not need it here.
rm $rustlib/*/bin/rust-objcopy

mkdir -p $out/usr/bin
for program in rustc rustdoc cargo; do
    ln -s ../lib/rust/bin/$program $out/usr/bin/$program
done

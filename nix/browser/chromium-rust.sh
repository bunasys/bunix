unpack $src
# where Chromium looks for its Rust (and crubit.sh installs Crubit)
prefix=/usr/lib/chromium-rust
# where chromium-rust-stage0.sh installs the Rust this is built from
stage0=/usr/lib/chromium-rust-stage0
# Rust's name for this machine: x86_64-linux-gnu is x86_64-unknown-linux-gnu
rust_target=${triplet/-linux-/-unknown-linux-}

cat > bootstrap.toml <<TOML
change-id = "ignore"

[build]
rustc = "$stage0/bin/rustc"
cargo = "$stage0/bin/cargo"
# every crate is in this source, and the network is not there
vendor = true
locked-deps = true
extended = true
# rustc-dev: rustc's crates, which Crubit is built against; rustfmt:
# Crubit and bindgen tidy the code they make with it
tools = ["rustc-dev", "rustfmt"]
docs = false
# the profiler's runtime (the compiler-rt in this source): Chromium's
# build expects it in the standard library, as in its own package
profiler = true
jobs = $jobs
description = "bunix chromium"

[install]
prefix = "$prefix"
# inside the prefix: nothing of this toolchain goes outside it
sysconfdir = "etc"

[rust]
# Chromium's Rust code uses nightly features; its own package is nightly
channel = "nightly"
# rustc finds its librustc_driver through \$ORIGIN/../lib
rpath = true
deny-warnings = false
download-rustc = false

[llvm]
download-ci-llvm = false

[target.$rust_target]
llvm-config = "/usr/bin/llvm-config"
TOML
export CARGO_NET_OFFLINE=true
python3 x.py build
DESTDIR=$out python3 x.py install

rustlib=$out$prefix/lib/rustlib
# the installer's lists, for its own uninstall script
rm $rustlib/{install.log,uninstall.sh,components,rust-installer-version} $rustlib/manifest-*
# LLVM's objcopy, linked against the system's libLLVM, which this
# package does not depend on (rustc has LLVM inside); nothing of
# Chromium's build uses it
rm $rustlib/*/bin/rust-objcopy
# Chromium reads the toolchain's version from here (build/config/
# rust.gni), as its own package has it
$out$prefix/bin/rustc --version > $out$prefix/VERSION
cat $out$prefix/VERSION

# The standard library's source with the crates it uses, which Chromium
# compiles itself (build/rust/std/rules/BUILD.gn); Rust's own rust-src
# leaves those crates out
rust_src=$rustlib/src/rust
mkdir -p $rust_src
cp -r library $rust_src/
# the crates are there: Chromium names each by its directory in vendor/
[ -d $rust_src/library/vendor ]

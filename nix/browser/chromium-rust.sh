unpack $src
prefix=/usr/lib/chromium-rust
stage0=/usr/lib/chromium-rust-stage0
# Rust's name for this machine: x86_64-linux-gnu is x86_64-unknown-linux-gnu
rust_target=${triplet/-linux-/-unknown-linux-}

# rustc-dev: rustc's crates, for Crubit; rustfmt: Crubit and bindgen tidy
# the code they make with it.  profiler: the profiler's runtime (the
# compiler-rt in this source), which Chromium's build expects in the
# standard library, as in its own package.  vendor, and no download:
# everything is in this source, and the network is not there.
cat > bootstrap.toml <<TOML
change-id = "ignore"

[build]
rustc = "$stage0/bin/rustc"
cargo = "$stage0/bin/cargo"
vendor = true
locked-deps = true
extended = true
tools = ["rustc-dev", "rustfmt"]
docs = false
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

cd $out$prefix
# the installer's lists, for its own uninstall script
rm -f lib/rustlib/install.log lib/rustlib/uninstall.sh lib/rustlib/manifest-* \
      lib/rustlib/components lib/rustlib/rust-installer-version
# LLVM's objcopy, linked against the system's libLLVM (rustc itself has
# LLVM inside): nothing of Chromium's build uses it (as ../base/rust.sh)
rm lib/rustlib/*/bin/rust-objcopy
# Chromium reads the toolchain's version from here (build/config/
# rust.gni), as its own package has it
bin/rustc --version > VERSION
cat VERSION
cd -

# The standard library's source with the crates it uses, which Chromium
# compiles itself (build/rust/std/rules/BUILD.gn); Rust's own rust-src
# leaves those crates out
library=$out$prefix/lib/rustlib/src/rust
mkdir -p $library
cp -r library $library/
[ -d $library/library/vendor ]

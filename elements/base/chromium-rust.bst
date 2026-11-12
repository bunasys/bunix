kind: manual
description: |
  Rust as Chromium builds with it -- only for building Hudhud
  (docs/browser.md), in /usr/lib/chromium-rust.  Not on the running
  system.

  Chromium 157 no longer builds with a Rust of the system's (bootstrap/
  rust.bst): parts of it (Blink's fonts, QR codes, CBOR, ...) call Rust
  through C++ bindings that Crubit (base/crubit.bst) generates, and that
  only works with the toolchain layout Chromium's own package has: a
  nightly rustc, the standard library's source (Chromium compiles the
  standard library itself) and rustc's own crates (rustc-dev), which
  Crubit's generator is built against.

  The nightly closest after the Rust commit Chromium 157 pins (tools/rust/
  update_rust.py: 1edd55dc, 2026-09-09): 94 commits later, none of which
  adds or removes a file of the standard library.  Built against LLVM 23
  (base/llvm-23.bst), the LLVM Chromium's clang is, rather than the LLVM
  Rust bundles.

  base/crubit.bst installs Crubit into this same directory, where
  Chromium looks for it.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- bootstrap/rust.bst
- base/llvm-23.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst
- base/python.bst

# rustc links LLVM 23 statically; LLVM needs zlib and zstd at run time
depends:
- base/zlib.bst
- base/zstd.bst

sources:
- kind: tar
  url: rust:dist/2026-09-10/rustc-nightly-src.tar.xz
  ref: af7f2374c83b75dc5d5122d55f9bee2c7889e4d40977290aedb219bf3aa0a99d

variables:
  rust-prefix: "%{prefix}/lib/chromium-rust"

environment:
  # everything is vendored in the source tarball; never the network
  CARGO_NET_OFFLINE: "true"

config:
  configure-commands:
  - |
    cat > bootstrap.toml <<TOML
    change-id = "ignore"

    [build]
    rustc = "%{bindir}/rustc"
    cargo = "%{bindir}/cargo"
    vendor = true
    locked-deps = true
    # rustc-dev: rustc's crates, for Crubit; rustfmt: Crubit and bindgen
    # tidy the code they generate with it
    extended = true
    tools = ["rustc-dev", "rustfmt"]
    docs = false
    # The profiler's runtime (from the compiler-rt in the source tarball):
    # Chromium's build tools expect it in the standard library, as in
    # Chromium's own package
    profiler = true
    # built on the Fly machine's 16 CPUs (tools/fly/README.md)
    jobs = 16
    description = "bunix chromium"

    [install]
    prefix = "%{rust-prefix}"
    # inside the prefix: nothing of this toolchain goes outside it
    sysconfdir = "etc"

    [rust]
    # Chromium's Rust code uses nightly features; Chromium's package is
    # nightly too
    channel = "nightly"
    # rustc finds its librustc_driver through \$ORIGIN/../lib
    rpath = true
    deny-warnings = false
    download-rustc = false

    [llvm]
    download-ci-llvm = false

    [target.x86_64-unknown-linux-gnu]
    llvm-config = "/usr/lib/llvm-23/bin/llvm-config"
    TOML
  build-commands:
  - python3 x.py build
  install-commands:
  - DESTDIR=%{install-root} python3 x.py install
  - |
    cd %{install-root}%{rust-prefix}
    # the installer's bookkeeping, for its own uninstall script
    rm -f lib/rustlib/install.log lib/rustlib/uninstall.sh lib/rustlib/manifest-* \
          lib/rustlib/components lib/rustlib/rust-installer-version
    # Chromium reads the toolchain's version from here (build/config/
    # rust.gni), as its own package has it
    bin/rustc --version > VERSION
    cat VERSION
  - |
    # The standard library's source with the crates it uses, which
    # Chromium compiles itself (build/rust/std/rules/BUILD.gn); Rust's own
    # rust-src component leaves those crates out
    src=%{install-root}%{rust-prefix}/lib/rustlib/src/rust
    mkdir -p $src
    cp -r library $src/
    test -d $src/library/vendor

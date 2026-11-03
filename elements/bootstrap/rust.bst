kind: manual
description: |
  Rust 1.99.1 -- rustc, the standard library and cargo -- compiled from source
  by the seed compiler, together with the LLVM it bundles.  rustc builds
  itself twice (stage 1 with the seed, stage 2 with stage 1), so nothing of
  the seed is left in what is installed.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- bootstrap/rust-seed.bst
- base/cmake.bst
- base/ninja.bst
- base/pkgconf.bst

# cargo links these (TLS and HTTP for crates.io, compression)
depends:
- base/openssl.bst
- base/curl.bst
- base/zlib.bst

sources:
- kind: tar
  url: rust:dist/rustc-1.99.1-src.tar.xz
  ref: 6451598a99e77f07571960f6b21d577399d3a30f33e80cbd2e3a4aae6535d265

variables:
  # rustc's own crates take a few GB each to compile, and LLVM's links more;
  # the build host has 7 GB
  rust-jobs: "4"

environment:
  # everything is vendored in the source tarball; never the network
  CARGO_NET_OFFLINE: "true"

config:
  configure-commands:
  - |
    cat > bootstrap.toml <<TOML
    change-id = "ignore"

    [build]
    rustc = "%{tools}/rust/bin/rustc"
    cargo = "%{tools}/rust/bin/cargo"
    vendor = true
    locked-deps = true
    extended = true
    tools = ["cargo"]
    docs = false
    jobs = %{rust-jobs}
    description = "bunix"

    [install]
    prefix = "/usr"
    sysconfdir = "/etc"
    docdir = "share/doc/rust"

    [rust]
    channel = "stable"
    # rustc finds its private librustc_driver in /usr/lib through
    # $ORIGIN/../lib; /usr/lib itself is not on the loader's path (glibc
    # searches the multiarch $libdir)
    rpath = true
    deny-warnings = false
    download-rustc = false

    [llvm]
    download-ci-llvm = false
    # the one architecture bunix runs on
    targets = "X86"
    experimental-targets = ""
    link-shared = false
    link-jobs = 1
    TOML
  build-commands:
  - python3 x.py build
  install-commands:
  - DESTDIR=%{install-root} python3 x.py install
  # the installer's bookkeeping, for its own uninstall script
  - |
    cd %{install-root}/usr/lib/rustlib
    rm -f install.log uninstall.sh manifest-* components rust-installer-version

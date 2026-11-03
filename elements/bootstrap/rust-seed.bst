kind: manual
description: |
  Binary Rust 1.98.0 from rust-lang.org: the compiler that compiles Rust
  1.99.1 (bootstrap/rust.bst), which only builds with its predecessor.  Like
  seed.bst it is a pinned binary that never reaches the final system; it is
  installed in /tools/rust.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: rust:dist/rustc-1.98.0-x86_64-unknown-linux-gnu.tar.xz
  directory: rustc
  ref: 0e37cb339f447fc44d6d781073bacacebfdc5612f2600e4c7e84c266f5f3aced
- kind: tar
  url: rust:dist/rust-std-1.98.0-x86_64-unknown-linux-gnu.tar.xz
  directory: rust-std
  ref: f5022e6c95a5ad23cca2513dc8281200f585fa188de6370aa37b128a43f876a3
- kind: tar
  url: rust:dist/cargo-1.98.0-x86_64-unknown-linux-gnu.tar.xz
  directory: cargo
  ref: 2f512d170d3dd23e16ababcda32ee2e6d5172d861a7af1f504e0b1e270cafab9

config:
  install-commands:
  - |
    for component in rustc rust-std cargo; do
      bash $component/install.sh --destdir=%{install-root} \
        --prefix=%{tools}/rust --disable-ldconfig
    done

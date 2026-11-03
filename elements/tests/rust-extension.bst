kind: manual
description: |
  The rust extension as it is on a running system: the root file system with
  sysext/gcc-tree.bst and sysext/rust-tree.bst over it, nothing else.
  Builds and runs a program with rustc, and a crate with cargo (offline: no
  dependencies) -- with the image's own shell and tools.

build-depends:
- system/rootfs.bst
- sysext/gcc-tree.bst
- sysext/rust-tree.bst

environment:
  HOME: /tmp/home

config:
  build-commands:
  - |
    rustc --version; cargo --version
    printf 'fn main() { println!("hello from Rust"); }\n' > hello.rs
    rustc -O hello.rs
    ./hello

  - |
    mkdir -p $HOME
    cargo new --offline --vcs none hello-cargo
    cd hello-cargo
    cargo build --offline --release
    ./target/release/hello-cargo

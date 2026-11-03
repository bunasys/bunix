kind: manual
description: |
  Proves the bootstrapped Rust: rustc and cargo build and run programs, and
  nothing of the seed compiler (/tools) is referenced by what was installed.

build-depends:
- bootstrap/build-env.bst
- bootstrap/rust.bst

environment:
  CARGO_NET_OFFLINE: "true"

config:
  build-commands:
  - rustc --version --verbose
  - cargo --version
  - printf 'fn main() { println!("hello from bunix Rust"); }\n' > hello.rs
  - rustc -O hello.rs && ./hello
  - cargo new --vcs none hello-cargo
  - cd hello-cargo && cargo build --release && ./target/release/hello-cargo
  - |
    leaked=0
    for f in /usr/bin/rustc /usr/bin/cargo /usr/lib/librustc_driver-*.so; do
      if readelf -d "$f" | grep -E 'RUNPATH|RPATH' | grep -q /tools; then
        echo "RUNPATH into /tools: $f"; leaked=1
      fi
      if readelf -d "$f" | grep NEEDED | grep -q /tools; then
        echo "NEEDED from /tools: $f"; leaked=1
      fi
    done
    [ -e /tools/rust ] && { echo "/tools/rust is staged -- the test sees the seed"; leaked=1; }
    exit $leaked

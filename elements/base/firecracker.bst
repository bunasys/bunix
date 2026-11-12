kind: manual
description: |
  Firecracker -- microVMs on KVM (/dev/kvm), with jailer, which starts it
  in a chroot, namespaces and cgroup of its own.  Upstream's own static
  release build, not built here: its seccomp filters (the system calls the
  VMM may make) exist only for the musl build, which bunix's Rust cannot
  target, and a glibc build runs with an empty filter.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: github:firecracker-microvm/firecracker/releases/download/v1.18.0/firecracker-v1.18.0-x86_64.tgz
  ref: 1ac8eec866dd5eea14efecf6323e22b23eea24054545338a5b34bc5bca6623cd

config:
  install-commands:
  - install -D -m 0755 firecracker-v1.18.0-x86_64 %{install-root}%{bindir}/firecracker
  - install -D -m 0755 jailer-v1.18.0-x86_64 %{install-root}%{bindir}/jailer

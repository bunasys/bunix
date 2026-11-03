kind: manual
description: |
  The swift extension as it is on a running system: the root file system
  with sysext/devel-tree.bst and sysext/swift-tree.bst over it, nothing
  else.  Compiles a program with swiftc, and builds and runs a package with
  the Swift package manager -- with the image's own shell and tools.

build-depends:
- system/rootfs.bst
- sysext/devel-tree.bst
- sysext/swift-tree.bst

environment:
  HOME: /tmp/home

config:
  build-commands:
  - |
    swift --version
    printf 'print("hello from Swift")\n' > hello.swift
    swiftc -O hello.swift -o hello
    ./hello

  - |
    # Foundation, which brings libxml2, ICU and the private libraries' users
    printf 'import Foundation\nprint("Foundation:", Date(timeIntervalSince1970: 0).ISO8601Format())\n' > found.swift
    swiftc found.swift -o found
    ./found

  - |
    mkdir -p $HOME hello-package
    cd hello-package
    swift package init --type executable --name hello
    swift build -c release
    swift run -c release hello

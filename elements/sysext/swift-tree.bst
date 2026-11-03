kind: manual
description: |
  The swift extension's /usr: swift.org's Swift toolchain for Linux -- a
  binary seed, like bootstrap/rust-seed.bst, pinned by checksum; building
  Swift from source is not done yet -- installed whole under
  /usr/lib/swift-toolchain -- as its own usr/: Swift's build engine finds
  the toolchain as the directory above usr/bin -- with commands in /usr/bin.

  Built for Ubuntu 24.04, it needs a few libraries in Ubuntu's form, which
  bunix's own differ from (sysext/swift-deps/): they go to the toolchain's
  private /usr/lib/swift-toolchain/deps/lib, and patchelf adds that
  directory to the search path of the programs that need them.  The system
  itself is not touched, and nothing leaks into programs built with Swift.

  Swift compiles and links through its own clang, which uses gcc's start
  files and libraries: the gcc extension has to be merged as well.
  tests/swift.bst builds programs with it; sysext/swift.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- tools/patchelf.bst
- sysext/swift-deps/ncurses.bst
- sysext/swift-deps/libedit.bst
- sysext/swift-deps/libxml2.bst
- sysext/swift-deps/sqlite.bst
- sysext/swift-deps/curl.bst

sources:
- kind: tar
  url: swift:swift-6.4.2-release/ubuntu2404/swift-6.4.2-RELEASE/swift-6.4.2-RELEASE-ubuntu24.04.tar.gz
  ref: 2e9ebec040ad459dd89a6d093a02d8314939135104850fae4d5c0f174fb3ba8c

variables:
  toolchain: /usr/lib/swift-toolchain

config:
  install-commands:
  - |
    mkdir -p %{install-root}%{toolchain}
    cp -a usr %{install-root}%{toolchain}/

  - |
    # Not for this system: Embedded Swift (microcontrollers, 724 MB),
    # WebAssembly, and the musl cross-compiling configurations (the Static
    # Linux SDK is a separate download)
    cd %{install-root}%{toolchain}/usr
    rm -rf lib/swift/embedded bin/wasmkit bin/wasm-ld bin/*-swift-linux-musl-*.cfg local

  - |
    # the private libraries, without what only building against them needs
    deps=%{install-root}%{toolchain}/deps
    mkdir -p $deps
    cp -a %{toolchain}/deps/lib $deps/
    rm -rf $deps/lib/pkgconfig $deps/lib/cmake $deps/lib/*.la
    find $deps/lib -name '*.so' -type l -delete

  - |
    # Each program and library that needs one of the private libraries
    # finds it through its search path (RUNPATH), relative to itself.  The
    # private libraries find each other the same way.
    cd %{install-root}%{toolchain}
    private='libncurses\.so|libtinfo\.so|libpanel\.so|libform\.so|libedit\.so|libxml2\.so|libsqlite3\.so|libcurl\.so'
    find usr/bin usr/lib -type f | while read -r f; do
      file -b "$f" | grep -q '^ELF' || continue
      patchelf --print-needed "$f" | grep -qE "^($private)" || continue
      dir=$(dirname "$f")
      relative=$(realpath --relative-to="$dir" deps/lib)
      patchelf --add-rpath "\$ORIGIN/$relative" "$f"
      echo "$f: \$ORIGIN/$relative"
    done
    for f in deps/lib/*.so.*; do
      [ -L "$f" ] || patchelf --set-rpath '$ORIGIN' "$f"
    done

  - |
    # The commands in /usr/bin, as scripts that put the toolchain's bin/
    # first in PATH and start the real program -- as swiftly, Swift's own
    # toolchain manager, does.  Not symbolic links: the package manager
    # finds the rest of the toolchain (swiftc, swift-autolink-extract,
    # libclang) by looking up swiftc in PATH, and would take /usr/bin (or
    # /usr/sbin, its alias) for the toolchain.
    mkdir -p %{install-root}%{bindir}
    for command in swift swiftc swift-build swift-run swift-test swift-package \
                   swift-sdk swift-format sourcekit-lsp lldb docc; do
      printf '#!/bin/sh\nPATH=%{toolchain}/usr/bin:$PATH exec %{toolchain}/usr/bin/%s "$@"\n' \
        $command > %{install-root}%{bindir}/$command
      chmod 0755 %{install-root}%{bindir}/$command
    done

  - |
    # sysext merges this only into the release it was built for
    mkdir -p %{install-root}/usr/lib/extension-release.d
    printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=x86-64\n' %{release-version} \
      > %{install-root}/usr/lib/extension-release.d/extension-release.swift
    du -sh %{install-root}/usr

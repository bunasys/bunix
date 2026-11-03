kind: manual
description: |
  The rust extension's /usr: rustc, the standard library and cargo, as the
  bootstrap built them from source (bootstrap/rust.bst).  rustc links
  through cc, so the devel extension has to be merged as well.
  tests/rust-extension.bst builds programs with it; sysext/rust.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- filename: bootstrap/rust.bst
  config:
    location: "%{sysroot}"

config:
  install-commands:
  # (staged dependencies are read-only: the work happens on a copy)
  - cp -a %{sysroot}/usr %{install-root}/

  - |
    # Only rustc, cargo and the standard library.  The rest of the staged
    # tree -- Rust's dependencies (OpenSSL, curl, zlib), which the root file
    # system has already, documentation, shell completions -- goes.
    cd %{install-root}/usr
    keep=$(mktemp -d)
    mkdir -p $keep/bin $keep/lib
    mv bin/rustc bin/cargo bin/rust-gdb bin/rust-gdbgui bin/rust-lldb $keep/bin/
    mv lib/librustc_driver-*.so lib/rustlib $keep/lib/
    rm -rf ./*
    mv $keep/bin $keep/lib .
    rmdir $keep

  - |
    # Programs and shared libraries without debug information.  The
    # standard library's .rlib files are kept whole: rustc reads them.
    cd %{install-root}/usr
    find . -type f | while read -r f; do
      case $(file -b "$f") in
        ELF*executable*|ELF*"shared object"*) strip --strip-unneeded "$f" ;;
      esac
    done

  - |
    mkdir -p %{install-root}/usr/lib/extension-release.d
    printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=x86-64\n' %{release-version} \
      > %{install-root}/usr/lib/extension-release.d/extension-release.rust
    du -sh %{install-root}/usr
    find %{install-root}/usr -maxdepth 3 | head -20

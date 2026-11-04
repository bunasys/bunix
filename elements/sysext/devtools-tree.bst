kind: manual
description: |
  The devtools extension's /usr: sysext/devtools-content.bst minus every
  file the root file system already has, and without headers and static
  libraries -- the gcc extension is for building.  It needs no other
  extension.  tests/devtools.bst uses it; sysext/devtools.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs
- filename: sysext/devtools-content.bst
  config:
    location: "%{sysroot}"

config:
  install-commands:
  # (staged dependencies are read-only: the work happens on a copy)
  - cp -a %{sysroot}/usr %{install-root}/

  - |
    # Paths the root file system has stay the root file system's, even
    # where the bytes differ (it strips its binaries).
    cd %{install-root}/usr
    find . ! -type d | while read -r f; do
      if [ -e "/rootfs/usr/$f" ] || [ -L "/rootfs/usr/$f" ]; then
        rm -f "$f"
      fi
    done

  - |
    # What is for building software (the gcc extension has that), and
    # documentation and translations.  The programs are the dependencies'
    # own (ncurses, curl, expat, openssl, bzip2), not tools this extension
    # is for.
    cd %{install-root}/usr
    rm -rf include lib/*/pkgconfig lib/*/cmake share/pkgconfig share/aclocal \
           share/man share/info share/doc share/locale share/bash-completion share/zsh
    cd bin
    rm -f tic infocmp toe tabs captoinfo infotocap ncurses6-config curl-config \
          xmlwf c_rehash bzip2 bunzip2 bzcat bzip2recover bzdiff bzgrep bzmore \
          bzless bzcmp bzegrep bzfgrep
    cd ..
    find lib -maxdepth 2 \( -name '*.a' -o -name '*.la' \) -delete
    find . -type d -empty -delete

  - |
    # Programs and shared libraries without debug information, as in the
    # root file system
    cd %{install-root}/usr
    find . -type f | while read -r f; do
      case $(file -b "$f") in
        ELF*executable*|ELF*"shared object"*) strip --strip-unneeded "$f" ;;
      esac
    done

  - |
    # sysext merges this only into the release it was built for
    # (SYSEXT_LEVEL in os-release, written by system/rootfs.bst)
    mkdir -p %{install-root}/usr/lib/extension-release.d
    printf 'ID=bunix\nSYSEXT_LEVEL=%s\nARCHITECTURE=x86-64\n' %{release-version} \
      > %{install-root}/usr/lib/extension-release.d/extension-release.devtools
    du -sh %{install-root}/usr

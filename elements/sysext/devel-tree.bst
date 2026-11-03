kind: manual
description: |
  The devel extension's /usr: sysext/devel-content.bst minus every file the
  root file system already has, so merging it over /usr only adds --
  compilers, headers, build tools -- and changes nothing that is there.
  tests/devel.bst builds software with it; sysext/devel.bst packs it.

(@): include/release.yml

build-depends:
- bootstrap/build-env.bst
- filename: system/rootfs.bst
  config:
    location: /rootfs
- filename: sysext/devel-content.bst
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
    # Not needed to build anything: documentation and translations; what
    # system/rootfs.bst removes on purpose (systemd's unused helpers and
    # units, terminfo beyond the common terminals, ...) and must not come
    # back with the extension; and the largest pieces nobody builds with --
    # Python's static library and IDE, gcc's LTO dump tool, glibc's locale
    # sources.
    cd %{install-root}/usr
    rm -rf share/man share/info share/doc share/locale share/gtk-doc \
           lib/systemd lib/environment.d lib/modprobe.d lib/modules-load.d \
           lib/binfmt.d lib/dbus-1.0 share/systemd share/factory share/polkit-1 \
           share/terminfo share/i18n share/bash-completion share/zsh \
           bin/fish_key_reader bin/lto-dump \
           lib/python3.*/idlelib lib/python3.*/test lib/python3.*/config-*/*.a
    find . -type d -empty -delete

  - |
    # Programs and shared libraries without debug information, as in the
    # root file system.  Object files and static libraries are kept whole.
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
      > %{install-root}/usr/lib/extension-release.d/extension-release.devel
    du -sh %{install-root}/usr

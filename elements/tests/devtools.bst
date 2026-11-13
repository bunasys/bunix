kind: manual
description: |
  The devtools extension as it is on a running system: the root file
  system with sysext/devtools-tree.bst over it, and no gcc extension --
  devtools works on its own.

build-depends:
- system/rootfs.bst
- sysext/devtools-tree.bst

config:
  build-commands:
  - |
    git init -q repo
    cd repo
    echo hello > README
    git add README
    git -c user.name=test -c user.email=test@bunix commit -q -m first
    git log --oneline | grep -q first
    git grep -P 'hel+o' > /dev/null

  - |
    file -b /usr/bin/bash | grep -q '^ELF 64-bit'
    echo 'zip me' > note.txt
    bsdtar -a -cf note.zip note.txt
    mkdir unzipped
    cd unzipped
    unzip -q ../note.zip
    test "$(sha256sum < note.txt)" = "$(sha256sum < ../note.txt)"

  - |
    for cmd in "gdb --version" "gdbserver --version" "strace -V" \
               "firecracker --version" "jailer --version"; do
      out=$($cmd 2>&1) || true
      echo "$out" | head -1
      case $out in
        *"error while loading shared libraries"*) echo "BROKEN: $cmd"; exit 1 ;;
      esac
    done

  - |
    # the VMM itself starts (it needs /dev/kvm only to run a VM)
    firecracker --version | grep -q '^Firecracker v'
    jailer --version | grep -q '^Jailer v'

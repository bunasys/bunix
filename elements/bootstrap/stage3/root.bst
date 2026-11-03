kind: script
description: |
  The stage-3 root: everything stages 1 and 2 put in /sysroot, moved to /.
  Stage 3 builds inside this alone -- the seed is gone from here on.

build-depends:
- bootstrap/seed.bst
- bootstrap/stage1.bst
- bootstrap/stage2.bst

config:
  commands:
  - cp -a %{sysroot}/. %{install-root}/
  - |
    cd %{install-root}
    # merged /usr, as UAPI.9 lays it out
    if [ -d usr/sbin ]; then cp -a usr/sbin/. usr/bin/ && rm -rf usr/sbin; fi
    ln -s bin usr/sbin
    ln -s usr/bin bin
    ln -s usr/bin sbin
    ln -s usr/lib lib
    mkdir -p etc root tmp var/tmp
    chmod 1777 tmp var/tmp
    # some build systems look up the current user
    printf 'root:x:0:0:root:/root:/bin/bash\nnobody:x:65534:65534:nobody:/:/bin/false\n' > etc/passwd
    printf 'root:x:0:\nnogroup:x:65534:\n' > etc/group

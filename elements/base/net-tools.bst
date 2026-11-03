kind: manual
description: |
  net-tools -- ifconfig, route, netstat, arp, mii-tool: the classic network
  commands, next to ip (busybox) and networkctl

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: sourceforge:net-tools/net-tools-2.10.tar.xz
  ref: b262435a5241e89bfa51c3cabd5133753952f7a7b7b93f32e08cb9d96f580d69

config:
  configure-commands:
  # `make config` asks one question per feature; the defaults are what Arch
  # and Debian build with.  Only hostname is turned off -- uutils provides it.
  # yes(1) dies of SIGPIPE once make has its answers, so config.h appearing
  # is the test, not the pipeline's status.
  - yes "" | make config > /dev/null || true
  - test -f config.h
  - |
    sed -i 's/^#define HAVE_HOSTNAME_TOOLS 1/#define HAVE_HOSTNAME_TOOLS 0/;
            s/^#define HAVE_HOSTNAME_SYMLINKS 1/#define HAVE_HOSTNAME_SYMLINKS 0/' config.h
    sed -i 's/^HAVE_HOSTNAME_TOOLS=1/HAVE_HOSTNAME_TOOLS=0/;
            s/^HAVE_HOSTNAME_SYMLINKS=1/HAVE_HOSTNAME_SYMLINKS=0/' config.make
  build-commands:
  - make
  install-commands:
  - make DESTDIR=%{install-root} install
  # it installs into /bin and /sbin, which on bunix are /usr/bin
  - |
    cd %{install-root}
    mkdir -p .%{bindir}
    mv bin/* sbin/* .%{bindir}/
    rmdir bin sbin

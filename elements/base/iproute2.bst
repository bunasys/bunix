kind: manual
description: |
  iproute2 -- ip (addresses, routes, links), ss (sockets) and bridge, in
  place of BusyBox's ip.  Without tc and the other subsystems' tools
  (devlink, rdma, ...), which nothing here uses.

(@): include/system.yml

build-depends:
- bootstrap/build-env.bst
- base/pkgconf.bst

depends:
- base/libmnl.bst

sources:
- kind: tar
  url: kernel:linux/utils/net/iproute2/iproute2-7.3.0.tar.xz
  ref: 5c1789d290bba048a6135ed1ab81b0402dd0fb528d1f1421765c42b1fc3d6289

variables:
  iproute2-make: >-
    make SUBDIRS="lib ip bridge misc" PREFIX=%{prefix} SBINDIR=%{bindir}
    CONF_USR_DIR=%{prefix}/share/iproute2 CCOPTS="%{cflags}"

config:
  configure-commands:
  # no libbpf, libelf, SELinux or libcap: their features are for tc and
  # containers
  - ./configure --prefix=%{prefix} --libdir=%{libdir} --libbpf_force off
  build-commands:
  - "%{iproute2-make}"
  install-commands:
  - "%{iproute2-make} DESTDIR=%{install-root} install"

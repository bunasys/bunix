kind: autotools
description: |
  smartmontools -- smartctl reads a drive's own health report (SMART):
  wear, reallocated sectors, temperature, its error log.  Without the
  smartd daemon, which mails reports and has no one to mail them to here.

build-depends:
- bootstrap/build-env.bst

sources:
- kind: tar
  url: sourceforge:smartmontools/smartmontools/7.5/smartmontools-7.5.tar.gz
  ref: 690b83ca331378da9ea0d9d61008c4b22dde391387b9bbad7f29387f2595f76e

variables:
  conf-local: >-
    --without-libsystemd --without-selinux --without-libcap-ng
    --without-nvme-devicescan --without-update-smart-drivedb --without-gnupg
    --without-initscriptdir --without-systemdsystemunitdir

config:
  install-commands:
    (>):
    - rm -rf %{install-root}%{bindir}/smartd %{install-root}%{sysconfdir}
    - rm -f %{install-root}%{bindir}/update-smart-drivedb

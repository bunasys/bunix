# Tools for working on software and on the running system, as a system
# extension: git, gdb, strace, file, bsdtar and unzip.  It needs no other
# extension; with gcc.feature for building.
#
#   mkdir -p /etc/sysupdate.d/devtools.feature.d
#   printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/devtools.feature.d/enable.conf
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
[Feature]
Description=Developer tools (git, gdb, strace, file, unzip)
Enabled=false

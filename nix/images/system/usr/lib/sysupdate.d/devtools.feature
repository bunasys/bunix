# Tools for working on software and on the running system, as a system
# extension: git, gdb, strace, file, bsdtar and unzip, and Nix
# (images/devtools.nix; after files/rootfs's).  It needs no other
# extension.
#
#   mkdir -p /etc/sysupdate.d/devtools.feature.d
#   printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/devtools.feature.d/enable.conf
#   /usr/lib/systemd/systemd-sysupdate update && systemctl restart systemd-sysext
# and, if the update brought a newer version of the system as well, a
# restart: the extension that came is that version's.
[Feature]
Description=Developer tools (git, gdb, strace, file, unzip, nix)
Enabled=false

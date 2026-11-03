# The toolchain as a system extension: gcc, binutils, the C library's and
# kernel's headers, make, pkgconf, the autotools, cmake, meson and ninja.
#
#   mkdir -p /etc/sysupdate.d/gcc.feature.d
#   printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/gcc.feature.d/enable.conf
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
#
# (`updatectl enable gcc` would write that file, but systemd 261's update
# service sees no update target while every transfer of the system belongs to
# a disabled feature -- as on the live ISO -- and answers "Invalid target".)
[Feature]
Description=GCC (gcc, g++, binutils, headers, make, cmake, meson)
Enabled=false

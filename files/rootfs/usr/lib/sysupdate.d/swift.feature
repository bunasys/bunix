# Swift (swiftc, the package manager, Foundation, lldb, sourcekit-lsp) as a system extension.  It builds through the devel extension's
# compiler and linker, so enable both:
#
#   for f in devel swift
#     mkdir -p /etc/sysupdate.d/$f.feature.d
#     printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/$f.feature.d/enable.conf
#   end
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
[Feature]
Description=Swift (swiftc, the package manager, Foundation, lldb, sourcekit-lsp)
Enabled=false

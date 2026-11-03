# Rust (rustc, cargo, the standard library) as a system extension.  It builds through the gcc extension's
# compiler and linker, so enable both:
#
#   for f in gcc rust
#     mkdir -p /etc/sysupdate.d/$f.feature.d
#     printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/$f.feature.d/enable.conf
#   end
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
[Feature]
Description=Rust (rustc, cargo, the standard library)
Enabled=false

# The graphical system as a system extension: Mesa, Wayland, libinput,
# seatd, fonts, niri with DMS and its login screen, GTK4, Ghostty and Buna
# Browser (docs/schematics.md, "Desktop or console").  Enabled by the installer for a desktop install.
#
#   mkdir -p /etc/sysupdate.d/desktop.feature.d
#   printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/desktop.feature.d/enable.conf
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
[Feature]
Description=Desktop (niri with DMS, GTK4, Ghostty, Hudhud)
Enabled=false

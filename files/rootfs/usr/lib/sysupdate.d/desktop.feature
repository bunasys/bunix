# The graphical system as a system extension: Mesa, Wayland, libinput,
# seatd, fonts, GTK4, Hyprland and Ghostty (docs/schematics.md, "Desktop or
# console").  Enabled by the installer for a desktop install.
#
#   mkdir -p /etc/sysupdate.d/desktop.feature.d
#   printf '[Feature]\nEnabled=true\n' > /etc/sysupdate.d/desktop.feature.d/enable.conf
#   /usr/lib/systemd/systemd-sysupdate update && systemd-sysext refresh
[Feature]
Description=Desktop (Mesa, Wayland, Hyprland, GTK4, Ghostty)
Enabled=false

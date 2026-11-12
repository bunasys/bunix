#!/bin/sh
# Starts Buna Browser (/usr/lib/buna-browser).
#
# --class: the Wayland app id, which matches buna-browser.desktop, so the
# compositor shows the right name and icon.  GTK 4 is the only GTK on the
# system (file dialogs, the system's fonts and colours).
exec /usr/lib/buna-browser/buna-browser --class=buna-browser --gtk-version=4 "$@"

#!/bin/sh
# Starts Hudhud (/usr/lib/hudhud).
#
# --class: the Wayland app id, which matches hudhud.desktop, so the
# compositor shows the right name and icon.  GTK 4 is the only GTK on the
# system (file dialogs, the system's fonts and colours).

# The browser was called Buna Browser until 2026-11-11: its profile moves
# to the new name once, instead of starting empty; the default browser
# setting names the new desktop entry, and the old cache goes
config=${XDG_CONFIG_HOME:-$HOME/.config}
if [ -d "$config/buna-browser" ] && [ ! -e "$config/hudhud" ]; then
  mv "$config/buna-browser" "$config/hudhud"
fi
if grep -q 'buna-browser\.desktop' "$config/mimeapps.list" 2> /dev/null; then
  sed -i 's/buna-browser\.desktop/hudhud.desktop/g' "$config/mimeapps.list"
fi
rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/buna-browser"

exec /usr/lib/hudhud/hudhud --class=hudhud --gtk-version=4 "$@"

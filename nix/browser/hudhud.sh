# What makes Chromium Hudhud on the desktop (files/hudhud/install): the
# launcher, the desktop entry and icons, and the first-run preferences.
# Small on purpose: a change to a preference or an icon builds this again,
# not Chromium.
cd $install

install -D -m 755 hudhud.sh $out/usr/bin/hudhud
install -D -m 644 hudhud.desktop $out/usr/share/applications/hudhud.desktop

# The hoopoe (files/hudhud/logo): icons/<size>.png for the sizes desktops
# ask for, and the SVG for any other size
for png in icons/*.png; do
    size=$(basename $png .png)
    install -D -m 644 $png $out/usr/share/icons/hicolor/${size}x${size}/apps/hudhud.png
done
install -D -m 644 icons/hudhud.svg $out/usr/share/icons/hicolor/scalable/apps/hudhud.svg

# First-run preferences, from the browser's own directory.  No policies:
# Hudhud's defaults are built in (docs/browser.md, "Defaults"), and any
# policy would show the browser as managed by an organization.
install -D -m 644 initial_preferences $out/usr/lib/hudhud/initial_preferences

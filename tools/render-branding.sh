#!/bin/sh
# Renders the Buna logo (files/branding/buna-logo.svg) to the PNG the boot
# splash shows.  Run by hand after the logo changes: the build has no SVG
# renderer yet (librsvg comes with the graphics stack).  Needs rsvg-convert.
set -eu
cd "$(dirname "$0")/.."
# The logo file has a white background; the boot screens are black, so the
# picture is rendered without it (transparent around the mark).
transparent=$(mktemp -t buna-logo).svg
sed 's|<rect x="-7" y="22" width="1001" height="1151" fill="#FFFFFF"></rect>||' \
  files/branding/buna-logo.svg > "$transparent"
rsvg-convert --height 256 --keep-aspect-ratio \
  "$transparent" -o files/plymouth/bunix/watermark.png
rm -f "$transparent"

# The boot image's splash (system/uki.bst, system/iso.bst): systemd's boot
# stub draws it, unscaled and centred, before the kernel starts -- the same
# picture and place as Plymouth's, so the hand-over does not show.  A plain
# 24-bit BMP is what the stub reads.  Needs ImageMagick.
magick files/plymouth/bunix/watermark.png -background black -flatten \
  -type truecolor BMP3:files/branding/splash.bmp

# Buna Browser's icons (base/buna-browser.bst): the boot splash's picture
# (the logo without its white background), centred on a transparent square,
# at the sizes desktops ask for.  Made from the PNG, not the SVG:
# ImageMagick's own SVG renderer loses the logo's gradients.
mkdir -p files/buna-browser/install/icons
for size in 16 24 32 48 64 128 256; do
  magick files/plymouth/bunix/watermark.png -background none -resize ${size}x${size} \
    -gravity center -extent ${size}x${size} files/buna-browser/install/icons/$size.png
done

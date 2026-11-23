#!/bin/sh
# Renders the Buna logo (files/branding/buna-logo.svg) to the pictures a
# boot shows:
#
#   files/branding/splash.bmp      the picture the kernel image carries
#                                  (nix/images/uki.nix)
#   files/branding/logo-mono.pbm   the mark in one colour, for the screen
#                                  of a kernel that stops (nix/boot/linux/)
#   files/plymouth/bunix/watermark.png
#                                  the first of these before it is a BMP;
#                                  what Plymouth showed, up to 0.4.0
#
# Run by hand after the logo changes: the build has no SVG renderer yet
# (librsvg comes with the graphics stack).  Needs rsvg-convert and
# ImageMagick.
set -eu
cd "$(dirname "$0")/.."
# The logo file has a white background; the boot screens are black, so the
# picture is rendered without it (transparent around the mark).
transparent=$(mktemp -t buna-logo).svg
sed 's|<rect x="-7" y="22" width="1001" height="1151" fill="#FFFFFF"></rect>||' \
  files/branding/buna-logo.svg > "$transparent"
rsvg-convert --height 256 --keep-aspect-ratio \
  "$transparent" -o files/plymouth/bunix/watermark.png

# The kernel image's splash (nix/images/uki.nix): systemd's boot stub
# draws it, unscaled and centred, before the kernel starts.  A plain
# 24-bit BMP is what the stub reads.
magick files/plymouth/bunix/watermark.png -background black -flatten \
  -type truecolor BMP3:files/branding/splash.bmp

# The mark in one colour, for the kernel: the screen of a kernel that
# stops shows its built-in logo, and takes one of this kind only
# (nix/boot/linux/).  What is not white in the drawing -- the frame, the
# letter and its dots -- is drawn, which in the file is what is white:
# the kernel draws a picture's white, on a black screen.  (So the white
# the drawing was rendered without is put under it again here.)  Made
# large and scaled down, for edges that are not ragged.  A plain-text PBM is what
# the kernel's build reads.
rsvg-convert --height 896 --keep-aspect-ratio "$transparent" -o "$transparent.png"
magick "$transparent.png" -background white -alpha remove -colorspace Gray \
  -threshold 88% -negate -resize x112 -threshold 50% \
  -compress none files/branding/logo-mono.pbm
rm -f "$transparent" "$transparent.png"

# Hudhud's icons are not the Buna logo any more: they come from
# files/hudhud/logo (its README says how to make them).

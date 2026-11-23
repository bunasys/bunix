#!/bin/sh
# Renders the Buna logo (files/branding/buna-logo.svg) to the pictures a
# boot shows:
#
#   files/plymouth/bunix/watermark.png
#                                  the mark, 256 dots high; what Plymouth
#                                  showed, up to 0.4.0
#   files/branding/splash.bmp      that as the picture the kernel image
#                                  carries (nix/images/uki.nix), and
#                                  src/boot-picture draws again: a BMP of
#                                  24 bits a dot, which is all that reads
#   files/branding/logo-mono.pbm   the mark in one colour, for the screen
#                                  of a kernel that stops (nix/boot/linux/)
#
# Run by hand after the logo changes: the build has no SVG renderer yet
# (librsvg comes with the graphics stack).  Needs rsvg-convert and
# ImageMagick.
set -eu
cd "$(dirname "$0")/.."
# The logo file has a white background; the boot screens are black, so the
# picture is rendered without it (transparent around the mark).
work=$(mktemp -d -t buna-logo)
trap 'rm -rf "$work"' EXIT
transparent=$work/transparent.svg
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
# (nix/boot/linux/).  The frame, the letter and its dots are drawn: all
# of the drawing but its near-white (88%), on white again.  In the file
# they are the white dots, since the kernel draws a picture's white, on
# a black screen.  Made large and scaled down to 112 dots high, for
# edges that are not ragged.  A plain-text PBM is what the kernel's
# build reads.
rsvg-convert --height 896 --keep-aspect-ratio "$transparent" -o "$work/large.png"
magick "$work/large.png" -background white -alpha remove -colorspace Gray \
  -threshold 88% -negate -resize x112 -threshold 50% \
  -compress none files/branding/logo-mono.pbm

# Hudhud's icons are not the Buna logo any more: they come from
# files/hudhud/logo (its README says how to make them).

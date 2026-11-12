#!/bin/sh
# Prepares Chromium's source for Hudhud (docs/browser.md), the same way on
# Linux (base/chromium.bst) and macOS (tools/build-macos.sh):
#
#   prepare-source.sh <chromium tree> <ungoogled-chromium> <files/hudhud> [<platform patch>...]
#
# ungoogled-chromium first, then the platform's own patches (macOS: its
# packaging's and Hudhud's macOS ones; Linux: none), then Hudhud.  The order
# matters: Hudhud's patches are made against a tree with all of those in.
set -eu

tree=$1
ungoogled=$2
hudhud=$3
shift 3

cd "$tree"

# ungoogled-chromium: no prebuilt binaries, its patches
python3 "$ungoogled/utils/prune_binaries.py" . "$ungoogled/pruning.list"
python3 "$ungoogled/utils/patches.py" apply . "$ungoogled/patches"

for patch in "$@"; do
  echo "Platform patch: $(basename "$patch")"
  patch -p1 --forward --silent < "$patch"
done

# Hudhud's changes to ungoogled-chromium's own (the Chrome Web Store, Secure
# DNS, building without private verification tokens)
for patch in "$hudhud"/ungoogled/patches/*.patch; do
  echo "Hudhud patch on ungoogled-chromium: $(basename "$patch")"
  patch -p1 --forward --silent < "$patch"
done

# Hudhud's own code (Shields, the password manager choice), the Shields
# engine's interface, and Hudhud's patches to Chromium
cp -R "$hudhud/chromium/." .
cp "$hudhud/shields/include/hudhud_shields.h" chrome/browser/hudhud_shields/
for patch in "$hudhud"/patches/[0-9]*.patch; do
  echo "Hudhud patch: $(basename "$patch")"
  patch -p1 --forward --silent < "$patch"
done

# Brave Search first in every country; the browser named Hudhud in its strings
python3 "$hudhud/scripts/brave-search-first.py" .
python3 "$hudhud/scripts/hudhud-name.py" .

# Last, as ungoogled-chromium's own builds do: Google's addresses replaced by
# ones that do not resolve, except in the files listed in
# ungoogled/not-substituted.list, which let the Chrome Web Store install and
# update extensions (docs/browser.md, "Extensions") -- the only Google
# addresses Hudhud may reach.  tools/chromium-update.py reads the same list.
substituted=$(mktemp)
grep -v -x -F -f "$hudhud/ungoogled/not-substituted.list" \
  "$ungoogled/domain_substitution.list" > "$substituted"
python3 "$ungoogled/utils/domain_substitution.py" apply \
  -r "$ungoogled/domain_regex.list" -f "$substituted" .
rm -f "$substituted"

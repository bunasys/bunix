# The bunix release being built, as a string: release-version of
# include/release.yml, which the elements read too.  One place says it.
#
# It is what a system says its version is (IMAGE_VERSION), the version in
# the labels of its /usr partitions and in the names of its update files:
# what an update is compared by (images/system.nix).
let
  lines = builtins.readFile ../include/release.yml;
  found = builtins.match ".*\n  release-version: ([0-9.]+)\n.*" lines;
in
if found == null
then throw "nix/release.nix: include/release.yml has no release-version of digits and dots"
else builtins.head found

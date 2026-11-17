# What every package build has in common (package.nix): the package's own
# script runs in the middle.
set -euo pipefail

# Needed at the end; a package whose tools lack it fails here, not after
# an hour of building.
command -v strip > /dev/null

# unpack <tarball> [directory]: the tarball's contents, without its top
# directory, into the current directory or the one named.
unpack() {
    mkdir -p "${2:-.}"
    tar -xf "$1" --strip-components=1 -C "${2:-.}"
}

# Nix passes the `cores` setting as it is, and 0 means all of them.
jobs=$NIX_BUILD_CORES
[ "$jobs" != 0 ] || jobs=$(nproc)
export MAKEFLAGS=-j$jobs

source "$script"

# Debugging information names the build directory and the store paths of
# sources.  Nix takes any store path it finds in the output for something
# the package needs to run, so the information goes, and the size with it.
# strip is given every file and refuses those that are not programs or
# libraries, hence no check of its result.
find "$out" -type f -exec strip --strip-debug {} + 2> /dev/null || true

# .la files record the build directory and the paths of build-time
# libraries, which only mislead later builds
find "$out" -name '*.la' -delete

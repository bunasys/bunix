# What every system package's build has in common (system-package.nix).  It
# runs inside the staged root (stage.sh); the package's own script runs in
# the middle.
#
# What a script can rely on:
#
#   - it is run by bash, with `set -euo pipefail`, in /build, as root of a
#     namespace that is nobody outside it;
#   - /usr is its dependencies; PATH is /usr/bin, then the bootstrap tools
#     the package asked for;
#   - $src is the source tarball; it installs with DESTDIR=$out;
#   - $triplet names the directory of libraries: /usr/lib/$triplet;
#   - `unpack`, parallel make and SOURCE_DATE_EPOCH, as in package.sh.
set -euo pipefail
cd /build

command -v strip > /dev/null

unpack() {
    mkdir -p "${2:-.}"
    tar -xf "$1" --strip-components=1 -C "${2:-.}"
}

jobs=$NIX_BUILD_CORES
[ "$jobs" != 0 ] || jobs=$(nproc)
export MAKEFLAGS=-j$jobs
export SOURCE_DATE_EPOCH=1

source "$script"

# As package.sh does, and for its reasons: debugging information out of
# programs, libraries, objects and archives, and no .la files.
find "$out" -type f | while read -r file; do
    magic=""
    read -r -N 7 magic < "$file" 2> /dev/null || true
    case $magic in
        $'\177ELF'*|'!<arch>')
            chmod u+w "$file"
            strip --strip-debug "$file"
            ;;
    esac
done
find "$out" -name '*.la' -delete

# A system package runs from /usr, in an image that has no store.  A store
# path in it is something it would look for there and not find.
if grep -r -l /nix/store "$out"; then
    echo "system-package.sh: the files above name the store" >&2
    exit 1
fi

# What it needs to run, for whatever stages it or puts it in an image.
# The one place a system package names the store: Nix reads it, the system
# never does.
for package in $depends; do
    echo "$package"
done > "$out/depends"

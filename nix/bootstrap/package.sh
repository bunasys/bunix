# What every package build has in common (package.nix): the package's own
# script runs in the middle.
set -euo pipefail

# Needed at the end; a package whose tools lack them fails here, not after
# an hour of building.
command -v strip > /dev/null
command -v readelf > /dev/null

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

# The time of the build, for whatever would record it (gcc's __DATE__,
# Python's compiled modules): always the same, the one Nix gives every
# file in the store, so that building twice gives the same bytes.
export SOURCE_DATE_EPOCH=1

source "$script"

# Debugging information names the build directory and the store paths of
# sources.  Nix takes any store path it finds in the output for something
# the package needs to run, so the information goes, and the size with it.
#
# Only from what the first bytes show to be a program, library or object
# file (\177ELF) or an archive of them (!<arch>).  strip will also take
# other formats it knows and write them back as it sees fit: it turned a
# kernel image into something no machine boots.
#
# .la files record the build directory and the paths of build-time
# libraries, which only mislead later builds.
#
# $outputs is the names of the package's outputs (out, lib), each the name
# of the variable that holds its path.
for output in $outputs; do
    installed=${!output}
    find "$installed" -type f | while read -r file; do
        magic=""
        read -r -N 7 magic < "$file" 2> /dev/null || true
        case $magic in
            $'\177ELF'*|'!<arch>')
                # installed read-only, as some packages do, it could not be
                # rewritten
                chmod u+w "$file"
                strip --strip-debug "$file"
                ;;
        esac
    done
    find "$installed" -name '*.la' -delete
done

# libraries_not_found <directory>: for each program and shared library in
# it, the libraries it asks for (NEEDED) that are in none of the
# directories it records for finding them (RUNPATH), nor in glibc's.
#
# A program whose build ignored LDFLAGS links all the same, and fails only
# when it is run, perhaps on another machine: it fails here instead.
#
# glibc's directory is the one the compiler builds for.  When the package
# is a glibc, that is the previous one, which has libraries of the same
# names.
glibc_libraries=$(dirname "$(gcc -print-file-name=libc.so.6)")
libraries_not_found() {
    local file dynamic directories library directory found
    find "$1" -type f \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) | while read -r file; do
        dynamic=$(readelf -d "$file" 2> /dev/null) || continue
        directories=$(echo "$dynamic" | sed -n 's/.*(R\(UN\)\?PATH).*\[\(.*\)\]/\2/p' | tr ':' ' ')
        # $ORIGIN in a recorded directory stands for the file's own
        directories=${directories//\$ORIGIN/$(dirname "$file")}
        for library in $(echo "$dynamic" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
            found=no
            for directory in $directories "$glibc_libraries"; do
                [ ! -e "$directory/$library" ] || found=yes
            done
            [ $found = yes ] || echo "$file needs $library"
        done
    done
}
for output in $outputs; do
    not_found=$(libraries_not_found "${!output}")
    if [ -n "$not_found" ]; then
        echo "$not_found" >&2
        echo "package.sh: the files above would not find these libraries when run" >&2
        exit 1
    fi
done

# What every system package's build has in common (system-package.nix).  It
# runs inside the staged root (stage.sh); the package's own script runs in
# the middle.
#
# What a script can rely on:
#
#   - it is run by bash, with `set -euo pipefail`, in /build, as root of a
#     namespace that is nobody outside it;
#   - /usr is its dependencies; PATH is /usr/bin, then the bootstrap tools
#     of the package's group, if it has any;
#   - $src is the source tarball, if the package has one; it installs with
#     DESTDIR=$out;
#   - $triplet names the directory of libraries, /usr/lib/$triplet, and
#     $configure_for_usr is the arguments that put an autoconf package where
#     UAPI.9 has things;
#   - `unpack <tarball> [directory]` unpacks one, without its top directory;
#   - make runs in parallel (MAKEFLAGS);
#   - SOURCE_DATE_EPOCH is set, for programs that record when they were
#     built.
#
# What is checked of its result is at the end of this file.
set -euo pipefail
cd /build

# Needed at the end; a package without them fails here, not after an hour
# of building.
command -v strip > /dev/null
command -v readelf > /dev/null

# --no-same-owner: as root, tar would give each file the owner the archive
# records for it, and this namespace has no other user to give it to.
unpack() {
    mkdir -p "${2:-.}"
    tar -xf "$1" --strip-components=1 --no-same-owner -C "${2:-.}"
}

# Nix passes the `cores` setting as it is, and 0 means all of them.
jobs=$NIX_BUILD_CORES
[ "$jobs" != 0 ] || jobs=$(nproc)
export MAKEFLAGS=-j$jobs

# The time of the build, for whatever would record it: always the same,
# the one Nix gives every file in the store.
export SOURCE_DATE_EPOCH=1

# UAPI.9: libraries in the directory named after the architecture; no
# /usr/sbin, no /usr/libexec, no /usr/com.  --bindir is spelled out because
# a package or two (util-linux) takes its absence, with a prefix of /usr,
# to mean a root with directories of its own, and installs into /bin.
configure_for_usr="--prefix=/usr --bindir=/usr/bin --sbindir=/usr/bin --libdir=/usr/lib/$triplet --libexecdir=/usr/lib --sysconfdir=/etc --localstatedir=/var --sharedstatedir=/var/lib"

source "$script"

# ---- The result ------------------------------------------------------------

fail() {
    echo "system-package.sh: $1" >&2
    exit 1
}

# Debugging information out, and the size with it.  Only from what the
# first bytes show to be a program, library or object file (\177ELF) or an
# archive of them (!<arch>): strip also takes other formats it knows and
# writes them back as it sees fit, and turned a kernel image into something
# no machine boots.  7 is the length of "!<arch>".
#
# Not from a program built elsewhere: it is shipped as the file that was
# published and pinned.
find "$out" -type f | while read -r file; do
    [ -z "$built_elsewhere" ] || break
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

# .la files record the build directory and the paths of build-time
# libraries, which only mislead later builds.
find "$out" -name '*.la' -delete

# A system package runs from /usr, in an image that has no store.  A store
# path in it, as text or as where a link points, is something it would
# look for there and not find.
#
# A program built elsewhere may name the store of whoever built it, as
# text, and nothing here can change that: those are not paths of this
# store (one that is, Nix itself refuses: allowedReferences).  What is
# asked of it is that it starts here: that it asks for this system's
# loader.
if [ -n "$built_elsewhere" ]; then
    with_another_loader=$(find "$out/usr/bin" -type f | while read -r program; do
        asks_for=$(readelf -l "$program" 2> /dev/null | sed -n 's/.*program interpreter: \(.*\)\]/\1/p')
        [ -z "$asks_for" ] || [ "$asks_for" = "$loader" ] || echo "$program asks for the loader $asks_for"
    done)
    if [ -n "$with_another_loader" ]; then
        echo "$with_another_loader" >&2
        fail "the programs above cannot start here"
    fi
elif grep -r -l /nix/store "$out"; then
    fail "the files above name the store"
fi
if find "$out" -type l -lname '*/nix/store/*' | grep .; then
    fail "the links above point into the store"
fi

# UAPI.9, and the loader: it looks for libraries in /usr/lib/$triplet and
# nowhere else, while the linker also looks in /usr/lib.  A library
# installed there links, and is not found when a program starts.
for directory in usr/lib64 usr/libexec usr/sbin usr/com usr/local bin sbin lib lib64; do
    [ ! -e "$out/$directory" ] || fail "it installed /$directory, which a bunix system does not have"
done
if find "$out/usr/lib" -maxdepth 1 -type f -name '*.so*' 2> /dev/null | grep .; then
    fail "the libraries above are in /usr/lib; they belong in /usr/lib/$triplet"
fi

# Every shared library that a program or library of the package asks for
# (NEEDED) is in the package or in what it declared it needs to run:
# $runtime_packages, from stage.sh.  One that reached the build through
# buildDepends, or was never declared, would be missing from an image.
#
# The loader looks in the directories the file records (RUNPATH), then in
# /usr/lib/$triplet.  A recorded directory is a path of the system, or
# $ORIGIN for the file's own (glibc's character-set converters find their
# shared tables beside themselves that way); a path of the system is
# looked for in each tree that will be laid over /.
trees="$out $runtime_packages"
is_in_the_system() {
    local tree
    for tree in $trees; do
        [ ! -e "$tree$1" ] || return 0
    done
    return 1
}
libraries_not_found() {
    local file dynamic recorded library directory found
    find "$out" -type f \( -perm -u+x -o -name '*.so' -o -name '*.so.*' \) | while read -r file; do
        dynamic=$(readelf -d "$file" 2> /dev/null) || continue
        recorded=$(echo "$dynamic" | sed -n 's/.*(R\(UN\)\?PATH).*\[\(.*\)\]/\2/p' | tr ':' ' ')
        for library in $(echo "$dynamic" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
            found=no
            for directory in $recorded /usr/lib/$triplet; do
                case $directory in
                    '$ORIGIN'*) [ ! -e "$(dirname "$file")${directory#\$ORIGIN}/$library" ] || found=yes ;;
                    *) ! is_in_the_system "$directory/$library" || found=yes ;;
                esac
            done
            [ $found = yes ] || echo "$file needs $library"
        done
    done
}
not_found=$(libraries_not_found)
if [ -n "$not_found" ]; then
    echo "$not_found" >&2
    fail "the libraries above are neither in the package nor in its depends"
fi

# Every script among its programs starts with the path of what runs it
# (#!/bin/sh, #!/usr/bin/perl).  That too has to be the package's own or a
# declared need, or the script is there and cannot start.  /bin and /sbin
# are /usr/bin; `env` finds the program it is given in /usr/bin.
scripts_without_interpreter() {
    local script first_line interpreter argument
    [ -d "$out/usr/bin" ] || return 0
    find "$out/usr/bin" -type f | while read -r script; do
        first_line=""
        read -r -n 200 first_line < "$script" 2> /dev/null || true
        case $first_line in
            '#!'*) ;;
            *) continue ;;
        esac
        read -r interpreter argument <<< "${first_line#\#!}"
        case $interpreter in
            /bin/*|/sbin/*|/usr/sbin/*) interpreter=/usr/bin/${interpreter##*/} ;;
        esac
        is_in_the_system "$interpreter" || echo "$script is run by $interpreter"
        if [ "$interpreter" = /usr/bin/env ]; then
            is_in_the_system "/usr/bin/${argument%% *}" || echo "$script is run by ${argument%% *}"
        fi
    done
}
without_interpreter=$(scripts_without_interpreter)
if [ -n "$without_interpreter" ]; then
    echo "$without_interpreter" >&2
    fail "what runs the scripts above is neither in the package nor in its depends"
fi

# What it needs to run, for whatever stages it or puts it in an image.
# The one place a system package names the store: Nix reads it, and so
# knows what the package needs; the system never does, and an image leaves
# the file out.
for package in $depends; do
    echo "$package"
done > "$out/depends"

#!/bin/bash
# Runs a program of bunix's system packages on a builder, whose own /usr
# is another system's: with /usr made of the packages, as a build has it
# (nix/stage.sh), but for a person and not for a build -- the network,
# the devices (/dev/kvm), and the directory it is run in are the
# builder's.
#
#   nix-build nix/base.nix -A qemu --no-out-link     # -> /nix/store/...-qemu-...
#   tools/nix-builder/with-usr.sh /nix/store/...-qemu-... -- qemu-system-x86_64 -version
#
# Before `--`: the packages, as nix-build prints them; what they need to
# run is added.  After it: the program and its arguments.  Files are
# found under the directory this is run in, and in /tmp; the rest of the
# builder's files is not there.
#
# No root is needed: it happens in a user namespace, where this user is
# root, and what is mounted there is gone when the program ends.  The
# program is to stay in the foreground: one that leaves another running
# behind it (qemu -daemonize) leaves it without its /usr.  A run that is
# cut off with its ssh session can leave its root's directory behind,
# empty, in /tmp (bunix-usr.*).
#
#   BUNIX_STORE  where the store's /nix is on this machine; default
#                ~/nix-root if there is one (a store under a home
#                directory, home-store/nix.conf), or nothing: /nix itself
#
# Needs: nix-store, as home-store/nix.conf or ../nix.conf sets it up.
set -euo pipefail

die() {
    echo "with-usr.sh: $*" >&2
    exit 1
}

# ---- In the namespace: the root ------------------------------------------------

# The second run of this file, by the first (below), which made the
# root's directory and found what goes into it.
make_root_and_run() {
    root=$1
    store=$2
    staged=$3
    shift 3
    here=$PWD

    cd "$root"
    mkdir -p usr etc dev proc tmp nothing "./$here"
    echo "root:x:0:0:root:/:/bin/sh" > etc/passwd
    echo "root:x:0:" > etc/group
    # for a program that looks names up (QEMU's network does, for its machine)
    if [ -e /etc/resolv.conf ]; then
        cp /etc/resolv.conf etc/resolv.conf
    fi

    # Each package's usr/ is a layer of /usr, read-only, and its etc/ is
    # copied (as stage.sh has it, where the mount's options are explained).
    layer_options=(-o lowerdir+=nothing)
    for package in $staged; do
        [ -d "$store$package" ] || die "$store$package is not there: is BUNIX_STORE right?"
        if [ -d "$store$package/usr" ]; then
            layer_options+=(-o "lowerdir+=$store$package/usr")
        fi
        if [ -d "$store$package/etc" ]; then
            cp -r --no-preserve=mode,ownership "$store$package/etc/." etc/
        fi
    done
    mount -t overlay overlay -o userxattr "${layer_options[@]}" usr
    ln -s usr/bin bin
    ln -s usr/lib lib
    # x86_64's programs ask for their loader in /lib64; aarch64's in /lib
    if [ -d usr/lib/x86_64-linux-gnu ]; then
        ln -s usr/lib/x86_64-linux-gnu lib64
    fi

    mount --rbind /dev dev
    mount --rbind /proc proc
    mount --bind /tmp tmp
    mount --bind "$here" "./$here"

    # unshare, with no namespace asked for, is chroot with a directory to
    # start in.  Found now: PATH is about to be the packages'.  And nothing
    # of the builder's own places goes with the program.
    unshare=$(command -v unshare)
    export PATH=/usr/bin HOME=/ TMPDIR=/tmp
    unset LD_LIBRARY_PATH
    exec "$unshare" --root=. --wd="$here" "$@"
}

# ---- Outside it ----------------------------------------------------------------

if [ "${1:-}" = in-namespace ]; then
    shift
    make_root_and_run "$@"
fi

packages=()
while [ $# -gt 0 ] && [ "$1" != -- ]; do
    packages+=("$1")
    shift
done
if [ ${#packages[@]} = 0 ] || [ $# -lt 2 ]; then
    die "usage: with-usr.sh <package>... -- <program> [<argument>...]"
fi
shift

default_store=
if [ -d "$HOME/nix-root/nix/store" ]; then
    default_store=$HOME/nix-root
fi
store=${BUNIX_STORE-$default_store}
case $store in
    ''|/*) ;;
    *) die "BUNIX_STORE is a path from /, not $store" ;;
esac

# The directory the program starts in is the builder's, at its own path
# in the root; under a path the root has of its own it would be mounted
# over it, or hidden by it.
case $PWD/ in
    /|/usr/*|/etc/*|/bin/*|/lib/*|/lib64/*|/dev/*|/proc/*)
        die "not from $PWD: the program's root has a $PWD of its own" ;;
esac

# what the packages need to run is what Nix knows them to name
staged=$(nix-store --query --requisites "${packages[@]}")

# The root's directory is removed when the program has ended, and nothing
# is mounted in it any more.
root=$(mktemp -d "${TMPDIR:-/tmp}/bunix-usr.XXXXXX")
trap 'rm -rf "$root"' EXIT
unshare -U -r -m "$BASH" "$0" in-namespace "$root" "$store" "$staged" "$@"

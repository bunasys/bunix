# Stages a build (stage.nix): gives it a root in which /usr is its
# dependencies, then runs $run_inside there.  The dependencies are system
# packages, each a store path with a usr/ in it; programs built for /usr
# only run where /usr is.
set -euo pipefail

# All of it happens in a user namespace of the build's own, where it may
# mount.  -U: the namespace; -r: as root in it, which is what may mount,
# and is nobody outside; -m: with mounts of its own, gone when the build
# ends.
if [ "${1:-}" != in-namespace ]; then
    exec unshare -U -r -m "$BASH" "$0" in-namespace
fi

mkdir -p root/usr root/etc root/var root/run root/nix root/dev root/proc root/tmp root/build
mkdir -p layers/nothing tmp work "$out"

# ---- What to stage ---------------------------------------------------------

# packages_in <closure files>: the store paths they list.  The files are
# Nix's (stage.nix); they also have the derivation each path was built
# from, which is not a package.
packages_in() {
    cat /dev/null "$@" | { grep '^/nix/store/' || true; } | { grep -v '\.drv$' || true; } | sort -u
}
shopt -s nullglob
# for system-package.sh: what the result may count on finding when it runs
export runtime_packages=$(packages_in closure-run-*)
staged=$(packages_in closure-run-* closure-build-*)

# Each package's usr/ is a layer of /usr.  Two packages with the same file
# would make /usr depend on the order of the layers, so that is an error,
# as is a path that is a directory in one and a file or link in another.
layer_count=0
: > files
: > directories
for package in $staged; do
    if [ ! -d $package/usr ] && [ ! -d $package/etc ]; then
        echo "stage.sh: $package has neither usr/ nor etc/: it is not a system package" >&2
        exit 1
    fi
    if [ -d $package/usr ]; then
        layer_count=$((layer_count + 1))
        ln -s $package/usr layers/$layer_count
        (cd $package/usr && find . ! -type d) >> files
        (cd $package/usr && find . -type d) >> directories
    fi
    if [ -d $package/etc ]; then
        cp -r --no-preserve=mode,ownership $package/etc/. root/etc/
    fi
done
sort files > files.sorted
sort -u directories > directories.sorted
in_two_packages=$(uniq -d files.sorted)
file_and_directory=$(comm -12 <(uniq files.sorted) directories.sorted)
if [ -n "$in_two_packages$file_and_directory" ]; then
    echo "$in_two_packages$file_and_directory" >&2
    echo "stage.sh: the paths above, under /usr, are in more than one staged package" >&2
    exit 1
fi

# ---- The root --------------------------------------------------------------

# /usr: the layers as one read-only tree.  One option per layer: all of
# them in a single option would be cut off at 256 characters.  The empty
# layer is because an overlay will not be made of one layer alone.
if [ $layer_count -gt 0 ]; then
    layer_options=(-o lowerdir+=layers/nothing)
    for ((number = 1; number <= layer_count; number++)); do
        layer_options+=(-o lowerdir+=layers/$number)
    done
    mount -t overlay overlay -o userxattr "${layer_options[@]}" root/usr
fi

# The store, for the source and the scripts: read-only, each of the
# build's inputs being a mount of its own under it.  Then the result, which
# the build writes.
mount --rbind /nix root/nix
findmnt --raw --noheadings --output TARGET --submounts root/nix | while read -r mounted; do
    mount -o remount,bind,ro "$mounted"
done
mount --bind "$out" "root$out"

# The kernel's file systems; a /tmp on disk; the build's directory.
mount --rbind /dev root/dev
mount --rbind /proc root/proc
mount --bind tmp root/tmp
mount --bind work root/build

# The links of a UAPI.9 root.  /lib64 only where the loader is asked for
# there (architecture.nix).
ln -s usr/lib root/lib
case $loader in
    /lib64/*) ln -s usr/lib/$triplet root/lib64 ;;
esac

# /bin/sh: make runs every recipe line with it.  The system's own, once
# bash is staged; until then, the bootstrap's.
if [ -e root/usr/bin/sh ]; then
    ln -s usr/bin root/bin
else
    mkdir root/bin
    ln -s "$BASH" root/bin/sh
fi

[ -e root/etc/passwd ] || echo "root:x:0:0:root:/build:/bin/sh" > root/etc/passwd
[ -e root/etc/group ] || echo "root:x:0:" > root/etc/group

# ---- Into it ---------------------------------------------------------------

# chroot is found now: PATH is about to be what the build sees.  The
# system's programs first; the bootstrap's after, for what the system does
# not have yet.
chroot=$(command -v chroot)
export PATH=/usr/bin${bootstrap_path:+:$bootstrap_path}
export HOME=/build TMPDIR=/tmp TMP=/tmp TEMP=/tmp TEMPDIR=/tmp
cd root
exec "$chroot" . "$BASH" "$run_inside"

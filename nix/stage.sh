# Stages a build: gives it a root in which /usr is its dependencies, then
# runs $inside there.  The dependencies are system packages, each a store
# path with a usr/ in it (system-package.nix); programs built for /usr only
# run where /usr is.
#
# It runs twice.  First as the build starts, to work out what to stage;
# then again, started by itself in a user namespace, where it may mount.
set -euo pipefail

# The directory of libraries, by architecture, as project.conf has it.
case $system in
    aarch64-linux) triplet=aarch64-linux-gnu ;;
    x86_64-linux) triplet=x86_64-linux-gnu ;;
    *) echo "stage.sh: no library directory is known for $system" >&2; exit 1 ;;
esac
export triplet

if [ "${1:-}" != in-namespace ]; then
    mkdir -p root/usr root/etc root/nix root/dev root/proc root/tmp root/build lower

    # The closure-* files have each store path the dependencies need (among
    # other lines).  Each one's usr/ gets a short name: the list of them is
    # an option of mount, which has a length limit.
    staged=$(cat closure-* 2> /dev/null | grep '^/nix/store/' | grep -v '\.drv$' | sort -u || true)
    count=0
    for package in $staged; do
        [ -d $package/usr ] || continue
        count=$((count + 1))
        ln -s $package/usr lower/$count
    done
    export count

    # -U: a user namespace; -r: as root in it, which is what may mount;
    # -m: with mounts of its own, gone when the build ends.
    exec unshare -U -r -m "$BASH" "$0" in-namespace
fi

# ---- From here on, in the namespace --------------------------------------

# /usr: nothing, one package, or several laid over each other.  An overlay
# with no upper layer is read-only, as a bind mount of the store is.
case $count in
    0) ;;
    1) mount --bind lower/1 root/usr ;;
    *)
        layers=lower/1
        for ((number = 2; number <= count; number++)); do
            layers=$layers:lower/$number
        done
        mount -t overlay overlay -o lowerdir=$layers,userxattr root/usr
        ;;
esac

# The store, for the source, the scripts and $out; the kernel's file
# systems; a /tmp; and the build's own directory as /build.
mount --rbind /nix root/nix
mount --rbind /dev root/dev
mount --rbind /proc root/proc
mount -t tmpfs tmpfs root/tmp
mkdir work
mount --bind work root/build

# The links of a UAPI.9 root.  The loader is asked for as /lib/ld-linux-...
# (aarch64) or /lib64/ld-linux-... (x86_64).
ln -s usr/lib root/lib
ln -s usr/lib/$triplet root/lib64

# /bin/sh: make runs every recipe line with it.  The system's own, once
# bash is staged; until then, the bootstrap's.
if [ -e root/usr/bin/sh ]; then
    ln -s usr/bin root/bin
else
    mkdir root/bin
    ln -s "$BASH" root/bin/sh
fi

echo "root:x:0:0:root:/build:/bin/sh" > root/etc/passwd
echo "root:x:0:" > root/etc/group

# The system's programs first; the bootstrap's after, for what the system
# does not have yet.
chroot=$(command -v chroot)
export PATH=/usr/bin${toolsPath:+:$toolsPath}
export HOME=/build TMPDIR=/tmp
cd root
exec "$chroot" . "$BASH" "$inside"

set -eu

fail() {
    echo "sandbox: $1" >&2
    exit 1
}

file_system=$(echo /*)
echo "file system: $file_system"
[ "$file_system" = "/bin /build /dev /etc /nix /proc /tmp" ] || fail "unexpected directories in /"

# /bin/sh is the one program outside the store, and it is nix/sh.nix: a
# nix.conf that names an older one, or none, fails here
[ "$(echo /bin/*)" = "/bin/sh" ] || fail "/bin is not sh alone"
cmp -s /bin/sh $sh || fail "/bin/sh is not nix/sh.nix; see tools/nix-builder/nix.conf"

# only what a build declares is in its store: here the seed, sh and this
# script
store=$(echo /nix/store/*)
echo "store: $store"
[ "$(echo $store | wc -w)" = 3 ] || fail "store paths the build did not ask for"

echo "running as: $(id)"
[ "$(id -u)" != 0 ] || fail "the build runs as root"

# Each line of /proc/net/dev after its two header lines is one network
# interface; with no network there is only the loopback.
interfaces=$(tail -n +3 /proc/net/dev | cut -d: -f1 | tr -d ' ' | tr '\n' ' ')
echo "network interfaces: $interfaces"
[ "$interfaces" = "lo " ] || fail "the build has a network"

echo ok > $out

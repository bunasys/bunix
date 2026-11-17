set -eu

fail() {
    echo "sandbox: $1" >&2
    exit 1
}

file_system=$(echo /*)
echo "file system: $file_system"
[ "$file_system" = "/build /dev /etc /nix /proc /tmp" ] || fail "unexpected directories in /"

echo "running as: $(id)"
[ "$(id -u)" != 0 ] || fail "the build runs as root"

# Each line of /proc/net/dev after its two header lines is one network
# interface; with no network there is only the loopback.
interfaces=$(tail -n +3 /proc/net/dev | cut -d: -f1 | tr -d ' ' | tr '\n' ' ')
echo "network interfaces: $interfaces"
[ "$interfaces" = "lo " ] || fail "the build has a network"

echo ok > $out

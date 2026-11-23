set -eu
cd /build

fail() {
    echo "usr-staging: $1" >&2
    exit 1
}

# sixty packages: more than fit in one option of mount, which is how the
# layers of /usr were first given, and where staging stopped at thirty
[ "$(ls /usr/share/layers | wc -l)" = 60 ] || fail "/usr has $(ls /usr/share/layers | wc -l) of the 60 packages staged"
[ "$(cat /usr/share/layers/60)" = "layer 60" ] || fail "a staged file does not read as its package wrote it"

# A build is root here, and the store is its own files on a builder that
# runs Nix without root: nothing but mounts being read-only stops it.
! touch /usr/share/layers/new 2> /dev/null || fail "the build can write to /usr"
! touch $one_layer/usr/share/layers/new 2> /dev/null || fail "the build can write to a dependency in the store"
! sh -c "echo changed > $one_layer/usr/share/layers/1" 2> /dev/null || fail "the build can change a dependency's file"

echo ok > $out/result

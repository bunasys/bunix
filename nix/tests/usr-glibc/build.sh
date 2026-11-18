set -eu
cd /build

fail() {
    echo "usr-glibc: $1" >&2
    exit 1
}

case $system in
    aarch64-linux) loader=/lib/ld-linux-aarch64.so.1 ;;
    x86_64-linux) loader=/lib64/ld-linux-x86-64.so.2 ;;
esac

[ -e /usr/lib/$triplet/libc.so.6 ] || fail "the staged /usr has no glibc"
[ -e $loader ] || fail "there is no loader at $loader"

# Stage 1's gcc builds for stage 1's glibc unless told otherwise: the start
# files and libraries of the one in /usr, and the usual loader.
cp $hello_c hello.c
gcc hello.c -o hello -B/usr/lib/$triplet -Wl,--dynamic-linker=$loader

[ "$(./hello)" = "hello from C" ] || fail "the program did not run"
readelf -l hello | grep -q "interpreter: $loader\]" || fail "its loader is not $loader"
! grep -q /nix/store hello || fail "the program names the store"

mkdir -p $out/usr/bin
cp hello $out/usr/bin/

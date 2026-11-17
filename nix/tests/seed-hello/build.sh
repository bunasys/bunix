set -eu

fail() {
    echo "seed-hello: $1" >&2
    exit 1
}

# Compiled from copies here, not from their store paths: gcc records the
# name it was given in the program, and Nix would take a store path found
# there for something the program needs to run.
cp $hello_c hello.c
cp $hello_cc hello.cc

mkdir -p $out/bin
gcc -static hello.c -o $out/bin/hello-static
g++ -static hello.cc -o $out/bin/hello-cc-static

# A dynamic program names its loader by absolute path, and the usual one
# (/lib/ld-linux-aarch64.so.1) does not exist here: it has to be the seed's.
libc=$seed/sysroot/usr/lib
gcc hello.c -o $out/bin/hello-dynamic \
    -Wl,--dynamic-linker=$libc/ld-linux-aarch64.so.1 -Wl,-rpath,$libc

[ "$($out/bin/hello-static)" = "hello from C" ] || fail "hello-static"
[ "$($out/bin/hello-cc-static)" = "hello from C++, 3 stages to go" ] || fail "hello-cc-static"
[ "$($out/bin/hello-dynamic)" = "hello from C" ] || fail "hello-dynamic"

readelf -l $out/bin/hello-dynamic | grep -q "interpreter: $libc/" || fail "hello-dynamic's loader is not the seed's"
! grep -r -q -e $hello_c -e $hello_cc $out || fail "a source's store path is in the output"

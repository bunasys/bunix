set -eu

fail() {
    echo "stage1-hello: $1" >&2
    exit 1
}

# copies, so that no store path of a source is recorded (see seed-hello)
cp $hello_c hello.c
cp $hello_cc hello.cc

mkdir -p $out/bin
gcc hello.c -o $out/bin/hello
g++ hello.cc -o $out/bin/hello-cc

[ "$($out/bin/hello)" = "hello from C" ] || fail "hello"
[ "$($out/bin/hello-cc)" = "hello from C++, 3 stages to go" ] || fail "hello-cc"

for program in hello hello-cc; do
    readelf -l $out/bin/$program | grep -q "interpreter: $glibc/lib/" || fail "$program's loader is not stage 1's glibc"
done

# ld called without gcc also knows where the loader is
echo 'void _start(void) { for (;;); }' > start.c
gcc -c start.c
ld start.o -o start -lc
readelf -l start | grep -q "interpreter: $glibc/lib/" || fail "ld's default loader is not stage 1's glibc"

# The seed built stage 1, and that is all: its store path is in none of it.
for built in $out $glibc $binutils $gcc; do
    ! grep -r -q $seed $built || fail "the seed's store path is in $built"
done

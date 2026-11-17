set -eu

fail() {
    echo "stage2-hello: $1" >&2
    exit 1
}

# A build as packages do it: a tarball unpacked, patched, built by make.
mkdir source
cp $hello_c source/hello.c
printf 'hello: hello.c\n\t$(CC) hello.c -o hello\n' > source/Makefile
tar -cJf source.tar.xz source
rm -r source
tar -xf source.tar.xz
cd source
sed -i 's/hello from C/hello from stage 2/' hello.c
make CC=gcc
[ "$(./hello | gawk '{ print $NF }')" = 2 ] || fail "the program built by make did not run"

mkdir -p $out/bin
cp hello $out/bin/

# stage 2's packages may not name the seed (stage2.nix); nor does what
# they build
! grep -r -q $seed $out || fail "the seed's store path is in the output"

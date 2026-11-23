set -eu

fail() {
    echo "stage2-hello: $1" >&2
    exit 1
}

# A package as upstream would ship it: a tarball with a C file, a grammar
# for bison and a Makefile.  The recipe with a pipe needs /bin/sh.
mkdir hello-1.0
cp $hello_c hello-1.0/hello.c
cat > hello-1.0/sum.y <<'END'
%{
#include <stdio.h>
int yylex(void) { static int calls; return calls++ < 3 ? 'x' : 0; }
void yyerror(const char *message) { puts(message); }
%}
%%
xs: | xs 'x' { puts("x"); };
%%
int main(void) { return yyparse(); }
END
printf 'all: hello sum\nhello: hello.c\n\t$(CC) hello.c -o hello\nsum: sum.y\n\tbison -o sum.c sum.y\n\t$(CC) sum.c -o sum\n\t./sum | wc -l > count\n' > hello-1.0/Makefile
tar -cJf hello-1.0.tar.xz hello-1.0

# a change to it, as a patch
cp -r hello-1.0 changed
sed -i 's/hello from C/hello from stage 2/' changed/hello.c
diff -u hello-1.0/hello.c changed/hello.c > stage2.patch || true
rm -r hello-1.0 changed

tar -xf hello-1.0.tar.xz
cd hello-1.0
patch -p1 < ../stage2.patch
make CC=gcc

[ "$(./hello)" = "hello from stage 2" ] || fail "hello, patched and built by make, did not say so"
[ "$(cat count)" = 3 ] || fail "the parser bison generated did not run"
[ "$(find . -name '*.c' | wc -l)" = 2 ] || fail "find"
[ "$(python3 -c 'import json, re, subprocess; print(json.dumps([1]))')" = "[1]" ] || fail "python"
[ "$(gzip -c hello.c | gzip -dc | cmp - hello.c && echo same)" = same ] || fail "gzip"

mkdir -p $out/bin
cp hello $out/bin/

# stage 2's packages may not depend on the seed (stage2.nix); nor does
# what they build
! grep -r -q $seed $out || fail "the seed's store path is in the output"

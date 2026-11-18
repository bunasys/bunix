# What the system's compiler must do, with no flags for where anything is.
set -eu
cd /build

fail() {
    echo "usr-toolchain: $1" >&2
    exit 1
}

[ "$(command -v gcc)" = /usr/bin/gcc ] || fail "gcc is not the system's: $(command -v gcc)"
[ "$(command -v ld)" = /usr/bin/ld ] || fail "ld is not the system's: $(command -v ld)"

cp $hello_c hello.c
cp $hello_cc hello.cc
mkdir -p $out/usr/bin $out/usr/lib/$triplet
bin=$out/usr/bin
lib=$out/usr/lib/$triplet

# ---- C and C++, dynamic and static ---------------------------------------

gcc hello.c -o $bin/hello
g++ hello.cc -o $bin/hello-cc
gcc -static hello.c -o $bin/hello-static
[ "$($bin/hello)" = "hello from C" ] || fail "the C program did not run"
[ "$($bin/hello-cc)" = "hello from C++, with a vector of 3" ] || fail "the C++ program did not run"
[ "$($bin/hello-static)" = "hello from C" ] || fail "the static program did not run"
for program in hello hello-cc; do
    readelf -l $bin/$program | grep -q "interpreter: $loader\]" || fail "$program's loader is not $loader"
    ! readelf -d $bin/$program | grep -q -i -E 'rpath|runpath' || fail "$program records where its libraries are; in /usr it need not"
done
! readelf -l $bin/hello-static | grep -q interpreter || fail "hello-static has a loader: it is not static"

# ---- Threads that end early ----------------------------------------------
#
# glibc needs libgcc_s.so when a thread calls pthread_exit or is cancelled,
# and loads it by name: it is beside glibc, in /usr/lib/$triplet.
# --as-needed is what meson passes.
cat > thread.c <<'END'
#include <pthread.h>
#include <stdio.h>
#include <unistd.h>
static void *exits(void *result) { pthread_exit(result); }
static void *waits(void *unused) { for (;;) sleep(1); }
int main(void) {
    pthread_t thread;
    pthread_create(&thread, 0, exits, 0);
    pthread_join(thread, 0);
    pthread_create(&thread, 0, waits, 0);
    pthread_cancel(thread);
    pthread_join(thread, 0);
    puts("one thread exited, one was cancelled");
    return 0;
}
END
gcc thread.c -o $bin/thread
gcc -Wl,--as-needed thread.c -o $bin/thread-as-needed
for program in thread thread-as-needed; do
    [ "$($bin/$program)" = "one thread exited, one was cancelled" ] || fail "$program: pthread_exit or pthread_cancel"
done

# ---- Shared libraries in C++ ----------------------------------------------
#
# An exception thrown in the library and caught by the program.  The second
# library is linked as libtool links every C++ library: with -nostdlib and
# the libraries spelled out.  LD_LIBRARY_PATH because the libraries are in
# this test's result, not yet in /usr.
cat > greeting.cc <<'END'
#include <stdexcept>
void greet(bool politely) { if (!politely) throw std::runtime_error("caught what the library threw"); }
extern "C" int greet_from_c(void) { try { greet(false); } catch (const std::runtime_error &) { return 42; } return 0; }
END
cat > greeter.cc <<'END'
#include <iostream>
#include <stdexcept>
void greet(bool politely);
int main() {
    try { greet(false); } catch (const std::runtime_error &error) { std::cout << error.what() << std::endl; }
}
END
echo 'int greet_from_c(void); int main(void) { return greet_from_c() - 42; }' > greeter.c

g++ -shared -fPIC greeting.cc -o $lib/libgreeting.so
g++ -shared -fPIC -nostdlib greeting.cc -lstdc++ -lm -lc -lgcc_s -o $lib/libgreeting-libtool.so
g++ greeter.cc -o $bin/greeter -L$lib -lgreeting
g++ -Wl,--as-needed greeter.cc -o $bin/greeter-as-needed -L$lib -lgreeting
gcc greeter.c -o $bin/greeter-c -L$lib -lgreeting-libtool
export LD_LIBRARY_PATH=$lib
for program in greeter greeter-as-needed; do
    [ "$($bin/$program)" = "caught what the library threw" ] || fail "$program: a C++ shared library"
done
$bin/greeter-c || fail "a C program using a C++ library linked the way libtool does"
unset LD_LIBRARY_PATH

# ---- Optimisation at link time --------------------------------------------
#
# Across two files, which needs the linker to load gcc's plugin; then with
# one of them in a library made by plain ar, which needs ar to find it.
echo 'int answer(void) { return 42; }' > answer.c
echo 'int answer(void); int main(void) { return answer() - 42; }' > question.c
gcc -O2 -flto answer.c question.c -o $bin/lto
$bin/lto || fail "link-time optimisation"

gcc -O2 -flto -c answer.c question.c
ar rcs libanswer.a answer.o
gcc -O2 -flto question.o libanswer.a -o $bin/lto-library
$bin/lto-library || fail "link-time optimisation with a library made by ar"

# ---- Nothing names the store ----------------------------------------------

if grep -r -l /nix/store $out; then
    fail "the files above, built by the system's gcc, name the store"
fi

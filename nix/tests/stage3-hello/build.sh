# What the final compiler must do, with no flags for where anything is.
# test.nix adds the rule Nix checks at the end: what is built here needs
# neither the compiler nor anything from an earlier stage to run.
set -eu

fail() {
    echo "stage3-hello: $1" >&2
    exit 1
}

# copies, so that no store path of a source is recorded (see seed-hello)
cp $hello_c hello.c
cp $hello_cc hello.cc
mkdir -p $out/bin $out/lib

# ---- C and C++, dynamic and static ---------------------------------------

gcc hello.c -o $out/bin/hello
g++ hello.cc -o $out/bin/hello-cc
gcc -static hello.c -o $out/bin/hello-static
[ "$($out/bin/hello)" = "hello from C" ] || fail "the C program did not run"
[ "$($out/bin/hello-cc)" = "hello from C++, with a vector of 3" ] || fail "the C++ program did not run"
[ "$($out/bin/hello-static)" = "hello from C" ] || fail "the static program did not run"
for program in hello hello-cc; do
    readelf -l $out/bin/$program | grep -q "interpreter: $glibc/lib/" || fail "$program's loader is not stage 3's glibc"
done
! readelf -l $out/bin/hello-static | grep -q interpreter || fail "hello-static has a loader: it is not static"

# ---- Where glibc looks on the system it runs on ---------------------------
#
# The time zone is the system's; which libraries to load is never the
# system's to say (stage3/glibc.sh).
strings $glibc/lib/libc.so.6 | grep -q -x '/etc/localtime' || fail "glibc does not read the time zone from /etc/localtime"
for list in ld.so.cache ld.so.preload; do
    ! strings $glibc/lib/ld-linux-*.so.* | grep -q -x "/etc/$list" || fail "the loader reads /etc/$list"
done

# ---- Threads that end early ----------------------------------------------
#
# glibc needs libgcc_s.so when a thread calls pthread_exit or is cancelled.
# --as-needed is what meson passes: it drops libraries the program does not
# call into, and must not drop that one.
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
gcc thread.c -o $out/bin/thread
gcc -Wl,--as-needed thread.c -o $out/bin/thread-as-needed
for program in thread thread-as-needed; do
    [ "$($out/bin/$program)" = "one thread exited, one was cancelled" ] || fail "$program: pthread_exit or pthread_cancel"
done

# ---- Shared libraries in C++ ----------------------------------------------
#
# An exception thrown in the library and caught by the program.  The second
# library is linked as libtool links every C++ library: with -nostdlib and
# the libraries spelled out.  It has to find libstdc++.so by itself, for a
# C program that uses it.
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

g++ -shared -fPIC greeting.cc -o $out/lib/libgreeting.so
g++ -shared -fPIC -nostdlib greeting.cc -lstdc++ -lm -lc -lgcc_s -o $out/lib/libgreeting-libtool.so
uses_library="-L$out/lib -Wl,-rpath,$out/lib"
g++ greeter.cc -o $out/bin/greeter $uses_library -lgreeting
g++ -Wl,--as-needed greeter.cc -o $out/bin/greeter-as-needed $uses_library -lgreeting
gcc greeter.c -o $out/bin/greeter-c $uses_library -lgreeting-libtool
for program in greeter greeter-as-needed; do
    [ "$($out/bin/$program)" = "caught what the library threw" ] || fail "$program: a C++ shared library"
done
$out/bin/greeter-c || fail "a C program using a C++ library linked the way libtool does"

# ---- Optimisation at link time --------------------------------------------
#
# Across two files, which needs the linker to load gcc's plugin; then with
# one of them in a library, which needs gcc-ar (stage3.nix).
echo 'int answer(void) { return 42; }' > answer.c
echo 'int answer(void); int main(void) { return answer() - 42; }' > question.c
gcc -O2 -flto answer.c question.c -o $out/bin/lto
$out/bin/lto || fail "link-time optimisation"

gcc -O2 -flto -c answer.c question.c
gcc-ar rcs libanswer.a answer.o
gcc -O2 -flto question.o libanswer.a -o $out/bin/lto-library
$out/bin/lto-library || fail "link-time optimisation with a library made by gcc-ar"

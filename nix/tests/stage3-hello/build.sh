set -eu

fail() {
    echo "stage3-hello: $1" >&2
    exit 1
}

# copies, so that no store path of a source is recorded (see seed-hello)
cp $hello_c hello.c
cp $hello_cc hello.cc
mkdir -p $out/bin $out/lib

gcc hello.c -o $out/bin/hello
g++ hello.cc -o $out/bin/hello-cc
gcc -static hello.c -o $out/bin/hello-static
[ "$($out/bin/hello)" = "hello from C" ] || fail "hello"
[ "$($out/bin/hello-cc)" = "hello from C++, 3 stages to go" ] || fail "hello-cc"
[ "$($out/bin/hello-static)" = "hello from C" ] || fail "hello-static"
for program in hello hello-cc; do
    readelf -l $out/bin/$program | grep -q "interpreter: $glibc/lib/" || fail "$program's loader is not stage 3's glibc"
done

# A thread that ends with pthread_exit: glibc needs libgcc_s.so for it,
# and stage 1's gcc could not give it one.
cat > thread.c <<'END'
#include <pthread.h>
#include <stdio.h>
static void *worker(void *result) { pthread_exit(result); }
int main(void) {
    pthread_t thread;
    pthread_create(&thread, 0, worker, 0);
    pthread_join(thread, 0);
    puts("the thread exited");
    return 0;
}
END
gcc thread.c -o $out/bin/thread
[ "$($out/bin/thread)" = "the thread exited" ] || fail "pthread_exit"

# A shared library in C++, and an exception thrown in it and caught by the
# program: stage 1's gcc could not link the library.
cat > greeting.cc <<'END'
#include <stdexcept>
void greet(bool politely) { if (!politely) throw std::runtime_error("caught what the library threw"); }
END
cat > greeter.cc <<'END'
#include <iostream>
#include <stdexcept>
void greet(bool politely);
int main() {
    try { greet(false); } catch (const std::runtime_error &error) { std::cout << error.what() << std::endl; }
}
END
g++ -shared -fPIC greeting.cc -o $out/lib/libgreeting.so
g++ greeter.cc -o $out/bin/greeter -L$out/lib -lgreeting -Wl,-rpath,$out/lib
[ "$($out/bin/greeter)" = "caught what the library threw" ] || fail "a C++ shared library"

# Optimisation at link time, across two files: it needs the linker to load
# gcc's plugin.
echo 'int answer(void) { return 42; }' > answer.c
echo 'int answer(void); int main(void) { return answer() - 42; }' > question.c
gcc -O2 -flto answer.c question.c -o $out/bin/lto
$out/bin/lto || fail "link-time optimisation"

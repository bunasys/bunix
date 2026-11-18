# One function for each way a system package can be wrong; $case names the
# one to run (test.nix).
mkdir -p $out/usr/share $out/usr/bin $out/usr/lib/$triplet

store_path_in_file() {
    echo "the source was $src" > $out/usr/share/where
}

link_into_store() {
    ln -s $src $out/usr/share/source
}

# a C++ program needs libstdc++.so, which is gcc's; gcc is only in
# buildDepends
undeclared_library() {
    echo 'int main() { return 0; }' > main.cc
    g++ main.cc -o $out/usr/bin/program
}

# in /usr/lib, where the linker looks and the loader does not
library_outside_triplet() {
    echo 'int f(void) { return 0; }' > f.c
    gcc -shared -fPIC f.c -o $out/usr/lib/libf.so
}

$case

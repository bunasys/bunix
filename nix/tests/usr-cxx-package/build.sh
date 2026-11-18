cp $hello_cc hello.cc
mkdir -p $out/usr/bin
g++ hello.cc -o $out/usr/bin/hello-cc
[ "$($out/usr/bin/hello-cc)" = "hello from C++, with a vector of 3" ]

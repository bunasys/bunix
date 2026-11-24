# libfuse's own example of a file system, one file, "hello", which says
# "Hello World!": built against each libfuse the extension has, as
# fuse-hello (3) and fuse2-hello (2, its source in $libfuse2_source).
unpack $src
gcc $CFLAGS $LDFLAGS $(pkg-config --cflags fuse3) -o fuse-hello example/hello.c $(pkg-config --libs fuse3)
mkdir libfuse2
unpack $libfuse2_source libfuse2
gcc $CFLAGS $LDFLAGS $(pkg-config --cflags fuse) -o fuse2-hello libfuse2/example/hello.c $(pkg-config --libs fuse)
install -D -m 755 -t $out/usr/bin fuse-hello fuse2-hello

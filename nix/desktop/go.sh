# Go as the Go project publishes it, laid out as it lays itself out, in
# /usr/lib/go: it finds its standard library and tools from where it is.
unpack $src $out/usr/lib/go

# Go's defaults for every build that uses it: never the network.  A
# build gives it its modules (desktop/dms.sh), and Go does not go looking
# for a newer Go of its own.
goenv=$out/usr/lib/go/go.env
sed -i -e 's/^GOPROXY=.*/GOPROXY=off/' -e 's/^GOTOOLCHAIN=.*/GOTOOLCHAIN=local/' $goenv
grep -qx GOPROXY=off $goenv
grep -qx GOTOOLCHAIN=local $goenv

mkdir -p $out/usr/bin
ln -s ../lib/go/bin/go $out/usr/bin/go
ln -s ../lib/go/bin/gofmt $out/usr/bin/gofmt

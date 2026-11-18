set -eu

fail() {
    echo "libraries: $1" >&2
    exit 1
}

# built with zlib: its library asks for libz, and has the path of zlib's
# lib/ to find it by
magic=$file/lib/libmagic.so
readelf -d $magic | grep -q 'NEEDED.*libz\.so' || fail "libmagic was built without zlib"
readelf -d $magic | grep -q "runpath.*$zlib/lib" || fail "libmagic does not have the path of zlib's lib/"

# and finds it when it runs: -z looks inside a compressed file
echo "some text" | gzip > text.gz
file -z text.gz | grep -q 'ASCII text' || fail "file did not look inside a gzip file: $(file -z text.gz)"

echo ok > $out

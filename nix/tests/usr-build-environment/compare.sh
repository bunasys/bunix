set -eu
if ! diff -r $by_the_bootstrap/usr $by_the_system/usr; then
    echo "usr-build-environment: glibc built by the system differs from the one the bootstrap built" >&2
    exit 1
fi
echo same > $out/result

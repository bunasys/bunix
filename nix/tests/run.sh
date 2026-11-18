#!/bin/bash
# Runs every test, on a builder:  bash /bunix/nix/tests/run.sh
#
# A test is a directory here with a test.nix that builds when the test
# passes.  usr-rejects is the other kind: each of its attributes must fail
# to build, with the message its `expected` file has for it.
set -u
tests=$(dirname "$(readlink -f "$0")")
failed=0

for test in "$tests"/*/test.nix; do
    name=$(basename "$(dirname "$test")")
    [ "$name" != usr-rejects ] || continue
    if nix-build "$test" --no-out-link > /dev/null 2> "/tmp/test-$name.log"; then
        echo "pass  $name"
    else
        echo "FAIL  $name   (log: /tmp/test-$name.log)"
        failed=1
    fi
done

while IFS=: read -r attribute message; do
    message=${message# }
    log=/tmp/test-usr-rejects-$attribute.log
    if nix-build "$tests/usr-rejects/test.nix" -A "$attribute" --no-out-link > /dev/null 2> "$log"; then
        echo "FAIL  usr-rejects $attribute   (it built)"
        failed=1
    elif grep -q -F "$message" "$log"; then
        echo "pass  usr-rejects $attribute"
    else
        echo "FAIL  usr-rejects $attribute   (failed, but not with: $message; log: $log)"
        failed=1
    fi
done < "$tests/usr-rejects/expected"

exit $failed

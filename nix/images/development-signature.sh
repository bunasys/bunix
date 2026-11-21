# The signature of a test system's hash, made as a release's is, by
# tools/sign.sh: with the development key, which is a file, where bunix's
# is asked of a password manager.  So that every test build goes the way
# a release does.
set -euo pipefail
BUNIX_VERITY_KEY_FILE=$key BUNIX_VERITY_CERTIFICATE=$certificate \
    bash $sign $(cat $hash_file) > $out/signature

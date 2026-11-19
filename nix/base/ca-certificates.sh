# One file, as the curl project extracts it from Mozilla's: nothing to
# unpack or build.  cert.pem is where OpenSSL looks by default.
install -D -m 644 $src $out/etc/ssl/certs/ca-certificates.crt
ln -s certs/ca-certificates.crt $out/etc/ssl/cert.pem

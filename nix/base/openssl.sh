unpack $src

# OpenSSL's Configure is a perl program of its own, and is told the
# architecture by OpenSSL's name for it.
case $system in
    aarch64-linux) openssl_target=linux-aarch64 ;;
    x86_64-linux) openssl_target=linux-x86_64 ;;
    *) echo "openssl.sh: no OpenSSL target known for $system" >&2; exit 1 ;;
esac

./Configure $openssl_target --prefix=/usr --libdir=/usr/lib/$triplet \
    --openssldir=/etc/ssl shared no-static-engine no-tests no-docs
make
make DESTDIR=$out install_sw install_ssldirs
rm $out/usr/lib/$triplet/libssl.a $out/usr/lib/$triplet/libcrypto.a

# Perl scripts, which would make OpenSSL need perl to run: c_rehash, which
# `openssl rehash` replaces, and two helpers in /etc/ssl/misc.  The element
# keeps them: its image has perl.
rm $out/usr/bin/c_rehash
rm -r $out/etc/ssl/misc

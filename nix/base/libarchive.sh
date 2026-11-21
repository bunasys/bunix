unpack $src
# no XML (the xar format); no ACLs, as the element, which had no libacl
# to read them with
./configure $configure_for_usr --disable-static --enable-bsdtar --enable-bsdcat --enable-bsdunzip \
    --disable-bsdcpio --disable-acl --without-xml2 --without-expat \
    --without-libb2 --without-lzo2 --without-mbedtls --without-nettle
make
make DESTDIR=$out install
ln -s bsdunzip $out/usr/bin/unzip

unpack $src
# The database and its signature, as published: there is nothing to build.
install -D -m 644 regulatory.db $out/usr/lib/firmware/regulatory.db
install -D -m 644 regulatory.db.p7s $out/usr/lib/firmware/regulatory.db.p7s

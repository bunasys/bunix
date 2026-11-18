# The archive is the one program, rex.
tar -xf $src --no-same-owner
install -D -m 755 rex $out/usr/bin/rex

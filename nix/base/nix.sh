# The source is the one program, not an archive: nix, which is every one
# of its commands by the name it is run as.
install -D -m 755 $src $out/usr/bin/nix
for command in nix-build nix-channel nix-collect-garbage nix-copy-closure nix-daemon nix-env \
        nix-hash nix-instantiate nix-prefetch-url nix-shell nix-store; do
    ln -s nix $out/usr/bin/$command
done

# The daemon: started when something first asks it, through a socket
# that listens from the start of a system that has this.  The link that
# says so is made here, where for the system's own units a preset
# decides (images/system/): this comes in an extension, and no preset is
# applied to one.
install -D -m 644 -t $out/usr/lib/systemd/system $files/nix-daemon.socket $files/nix-daemon.service
mkdir -p $out/usr/lib/systemd/system/sockets.target.wants
ln -s ../nix-daemon.socket $out/usr/lib/systemd/system/sockets.target.wants/nix-daemon.socket

install -D -m 644 $files/nix.conf $out/usr/share/factory/etc/nix/nix.conf
install -D -m 644 $files/tmpfiles.d-nix.conf $out/usr/lib/tmpfiles.d/nix.conf

# ../autotools.sh's lines
unpack $src
./configure $configure_for_usr \
    --disable-nls --disable-alsamixer --disable-bat --disable-alsaconf --disable-alsaloop \
    --disable-xmlto --disable-rst2man --with-asound-state-dir=/var/lib/alsa
make
make DESTDIR=$out install

# Upstream's udev rule and unit restore a card's volumes when the card
# appears, which is before the extension is merged; and they go to /lib,
# which a bunix system does not have.  /var/lib/alsa, where the volumes
# are kept, the unit has systemd make (StateDirectory): an extension
# carries only /usr.
rm -r $out/lib $out/var

# alsactl from a unit of its own instead, upheld by multi-user.target
# (docs/desktop.md, "Units in an extension").  `restore` sets ALSA's
# defaults, unmuted, when nothing was saved yet; `store` saves them at
# shutdown.  No condition on a card being there: a unit whose condition
# fails ends inactive, and what upholds it starts it again and again.
# alsactl fails instead, and `-` lets it.
units=$out/usr/lib/systemd/system
install -D -m 644 /dev/stdin $units/alsa-restore.service <<'UNIT'
[Unit]
Description=Sound card volumes
After=systemd-sysext.service

[Service]
Type=oneshot
RemainAfterExit=yes
StateDirectory=alsa
ExecStart=-/usr/bin/alsactl restore
ExecStop=-/usr/bin/alsactl store
UNIT
install -D -m 644 /dev/stdin $units/multi-user.target.d/alsa-restore.conf <<'UNIT'
[Unit]
Upholds=alsa-restore.service
UNIT

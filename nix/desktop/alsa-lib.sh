# ../autotools.sh's lines
unpack $src
./configure $configure_for_usr --disable-static --without-debug --disable-python --disable-topology
make
make DESTDIR=$out install

# alsa.conf reads drop-ins from /etc/alsa/conf.d, which an extension
# cannot carry, and from /usr/share/alsa/alsa.conf.d too, where PipeWire
# puts the file that makes it ALSA's default device (desktop/pipewire.sh).
# That one first in the list, so that /etc's files still win.
conf=$out/usr/share/alsa/alsa.conf
sed -i 's|^\t\t\t"/var/lib/alsa/conf.d"$|\t\t\t"/usr/share/alsa/alsa.conf.d"\n\t\t\t"/var/lib/alsa/conf.d"|' $conf
grep -q '"/usr/share/alsa/alsa.conf.d"' $conf

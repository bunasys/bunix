# ALSA's use-case profiles of sound cards (UCM): for each card, which of
# its devices is a speaker, a headphone jack or a microphone, and how to
# switch them, which WirePlumber reads.  ucm2/ alone, under
# /usr/share/alsa where alsa-lib looks: the older ucm/ format is one
# alsa-lib has not read for years.  Used for upstream's profiles and for
# Aurora Silicon's of Apple's cards, which lie beside them.
unpack $src
mkdir -p $out/usr/share/alsa
cp -a ucm2 $out/usr/share/alsa/

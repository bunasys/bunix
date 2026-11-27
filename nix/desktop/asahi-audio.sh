# asahi-audio, Aurora Silicon's (docs/mac-speakers.md): each Mac's
# speaker processing as PipeWire filter chains (graph.json, its FIR
# filters as WAV files, and the microphones' mic.json), and the
# WirePlumber configuration that puts a Mac's speakers and microphones
# behind them.  Aurora's fork took out the speaker graphs of the J316,
# J413, J616 and J700 for speakerguardd 2; Aurora's patch ($patches) puts
# them back, since bunix runs speakersafetyd.  Data only: its Makefile
# copies.
unpack $src
for fix in $patches; do
    patch --fuzz=0 -p1 -i $fix
done
# -j1: the Makefile writes the graphs of Macs that share another's tuning
# (graph-j493.json from the J293's) in a target it does not order before
# the one that copies them; in parallel, a copy can miss them
make -j1 install DESTDIR=$out PREFIX=/usr
# Aurora's: the speakers' PCM wakes PipeWire on its own interrupts, not
# on a timer that an NTP correction of the clock throws off
install -m 644 $speaker_interrupts $out/usr/share/wireplumber/wireplumber.conf.d/99-aurora-speaker-irq.conf
# the J293's graph (mbp20), and one of those written from another's: the
# build fails here, rather than the speakers staying unprocessed on a Mac
[ -f $out/usr/share/asahi-audio/j293/graph.json ]
[ -s $out/usr/share/asahi-audio/j293/graph-j493.json ]

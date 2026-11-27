# A Mac's speakers

Found on mbp20 (MacBook Pro 13", M1, J293) with 0.5.3, 2026-11-27: the
sound card works (#33), the headphone jack plays, and the speakers are
silent.  Not a fault: Asahi's kernel driver (`snd_soc_macaudio`) turns
the four speaker amplifiers on only while speaker protection runs.

## Why the speakers need programs

- **Protection.** A Mac's speakers are driven past what they take for
  long.  macOS keeps them whole with a model of their coils' and magnets'
  temperature, fed by the amplifiers' voltage and current sense, which
  turns them down before they overheat.  On Linux that is
  **speakersafetyd**, a daemon: per-model tuning and floating point,
  which is no kernel's work.  The driver plays through the speakers only
  while it runs (`please_blow_up_my_speakers`, which skips that, stays
  0).
- **Sound.** Unprocessed, the speakers are thin.  **asahi-audio** is
  macOS's processing as a PipeWire filter chain: each model's FIR
  filters, EQ and limiting from **lsp-plugins**, the bass of
  **bankstown**, and for the microphones **triforce** (beamforming).
  They are LV2 plugins, which PipeWire loads with **lilv**.
- **Which output.** ALSA's UCM profiles for Apple's cards
  (**alsa-ucm-conf-asahi**, on top of **alsa-ucm-conf**): what is a
  speaker and what the jack, which WirePlumber reads.

## As Aurora Silicon has them

Aurora's distributions (`aurora-silicon/fedora-aurora`, `alarm-aurora`,
`nixos-aurora`) ship today:

- speakersafetyd 2.0.1 (crates.io), with Aurora's profiles for models
  upstream lacks, its udev rule, and a restart that starts warm: the
  daemon's flag in `/run/speakersafetyd` goes with its unit, so a
  restart within a boot took the speakers for cold
  (`50-aurora-warm-restart.conf`);
- their fork of asahi-audio (`aurora-silicon/asahi-audio`), and of
  alsa-ucm-conf-asahi;
- PipeWire 1.6.11 with eleven patches, five of them for a Mac's speakers:
  the filter graph's latency and software volume, and the ALSA plugin
  when the driver refuses to start the speakers' PCM (protection not
  granted yet, or just after a resume);
- bankstown, triforce, and lsp-plugins' LV2 plugins.  bankstown and
  triforce at the commits Aurora pins them to, which its asahi-audio is
  tuned with: they move together with asahi-audio (upstreams.yml has
  them untracked for that).

Their **speakerguardd 2**, which is to match macOS's protection exactly
from each Mac's own tuning, is alpha, and has the 13" MacBook Pro
M1/M2 (J293, J493) as "later": it replaces speakersafetyd when it is
ready for them.

## What bunix has, and lacks

PipeWire 1.6.11 and WirePlumber 0.5.19, in the desktop extension;
alsa-lib.  No alsa-ucm-conf, no LV2 host in PipeWire (`-Dlv2`), none of
the above.

Not the speakers' problem, though the report names it: Hudhud is a
"PipeWire ALSA" client and not a PulseAudio one because it is built
without PulseAudio (`use_pulseaudio = false`, nix/browser/chromium.sh):
ALSA's default device is PipeWire.

## Steps

Each tested on both architectures where it applies, and reviewed
(`/kz-review`), as the browser's were.  The packages go into the desktop
extension, with PipeWire; speakersafetyd and the Mac's profiles into
arm64's alone.

1. **LV2 in PipeWire.**  lv2 (headers), serd, sord, sratom, zix and lilv;
   PipeWire with `-Dlv2=enabled` and Aurora's five speaker patches.
   lsp-plugins' LV2 plugins without their windows (no X11), bankstown
   and triforce (Rust).  Test: the desktop test loads a filter chain
   with one plugin of each.  Chromium depends on PipeWire (screen
   sharing), so a change to PipeWire builds it again: on arm64 in the
   builder, from the compiler cache; on x86-64 on the Fly machine
   (tools/nix-fly.sh) before any x86-64 test, which would otherwise
   build it on the x86 builder, which has no room for it.
2. **The profiles.**  alsa-ucm-conf, and Aurora's alsa-ucm-conf-asahi
   over it.  Test: alsactl and WirePlumber read them on the test machine
   (no Apple card there: they load, and nothing changes for a virtio
   card).
3. **speakersafetyd** (arm64), from its crate and its Cargo.lock's
   crates, with Aurora's fixes, profiles, udev rule and warm restart.
   Started as upstream starts it: its udev rules (95, and Aurora's 96)
   ask for it (`SYSTEMD_WANTS`) when a Mac it has a profile for shows its
   speakers' sense PCM, and on no other machine.  The merge has udev go
   over the sound devices again (systemd-sysext.service.d/bunix.conf), so
   it starts at boot and after `bunix ext enable desktop` alike; and the
   extension's build counts a service its udev rules ask for as started
   (extension-parts.sh).  Test: on the arm64 test machine the program
   runs, udev takes its rules, and it is not started.  Each change of
   extensions starts it again if it is not running: speakerguardd, when
   it replaces it, masks it rather than stops it.
4. **asahi-audio**, Aurora's, at its pinned commit.  It has graphs for
   Macs whose speakers only speakerguardd protects (the J700, the
   MacBook Neo): there the graph's sink is the default and plays
   nothing.  Only Macs that speakersafetyd has a profile for play.  With
   no RealtimeKit, PipeWire's threads get their real-time priority from
   limits every session has (wireplumber.sh).  Test: the filter
   chain for a J293 loads in the arm64 test machine, though no card of
   its is there.
   Released together with steps 2 to 4, not before: with the profiles
   alone, a Mac's speakers are a device WirePlumber may choose, which the
   driver keeps silent until speakersafetyd runs.
5. **On mbp20**, which QEMU cannot stand in for:
   - after a start, speakersafetyd runs, and its journal says it began
     cold ("Startup mode: Cold boot");
   - after `systemctl restart speakersafetyd`, it says warm: Aurora's
     marker works under DynamicUser=;
   - after `bunix ext disable desktop` and `enable`, it runs again;
   - `wpctl status` shows "MacBook Pro J293 Speakers" as the default and
     no RawSpeakers; `pw-link -l` has the chain's four outputs linked one
     to one to the speakers' four channels; `pw-dump` has
     `api.alsa.disable-tsched = true` on them;
   - the speakers play, at 44.1 and 96 kHz, after a suspend too, without
     crackling under load (`pw-top`'s ERR column), and sound right;
   - the microphones: the "j293" source records (triforce);
   - `journalctl -u alsa-restore` has no EPERM over a few starts
     (speakersafetyd's locked controls).

   Then a release.

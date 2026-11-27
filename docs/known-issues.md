# Known issues

Small problems seen on real installs, to fix when there is time.  Newest
first; remove an entry when it is fixed.

## A Mac's microphones, on mbp20 (2026-11-27, test version 0.5.3.2)

- **The J293's internal microphones record silence**, though they work in
  macOS and the lid is open (logind's LidClosed is false).  The PipeWire
  side is right: the "MacBook Pro J293 Microphone" source (asahi-audio's
  mic.json) is the default, and is linked to RawMics.  Below it, the AOP
  card gives nothing: `arecord -D hw:AppleJ293HPAI,0 -f FLOAT_LE -c 3
  -r 48000` reads zeros and denormals (the same peak, 0.000714, in every
  try, with a tone playing on the speakers or not), and `hw:AppleJ293HPAI,1`
  (the low-power mics, S16_LE, 3 channels, 16 kHz) one constant value,
  31585, on every channel.  That is what Aurora's driver
  (sound/soc/apple/aop_lid.rs) says the mics read when the lid closes and
  they are cut off in hardware.  "Internal Mic Jack" reads on, and the
  kernel logs no error.  Not the AOP's sensors: with them built in
  (0.5.3.2), nothing changed; a J293 has no lid angle sensor.  Asked of
  Aurora Silicon, whose kernel (linux 9125b31) bunix builds:
  https://github.com/aurora-silicon/linux/issues/3378.

## DMS on niri, first tests in QEMU (2026-11-09, 0.3.0)

- **No usable GPU, no desktop.**  niri renders only through a GPU with a
  render node: on a machine Mesa has no driver for (NVIDIA: bunix builds
  no nouveau) or in a VM without 3D, the login screen stays black.
  Test VMs need `-device virtio-vga-gl -display egl-headless` (QEMU's GL
  modules); QEMU's screendump cannot capture that screen, VNC can.
- **No on-screen keyboard** on the login screen.

## Hudhud, first test in QEMU (2026-11-07)

- **The first-run screen still shows** ("The browser that gets more done",
  "Set Chromium as your default browser"), although initial_preferences
  sets `skip_first_run_ui` and `suppress_first_run_default_browser_prompt`.
  Check that Chromium reads /usr/lib/hudhud/initial_preferences, or
  whether this newer welcome screen needs a policy or a build flag.  (The
  Chromium name and logo on it are step 2 of docs/browser.md.)

## Seen on the testbed after a fresh 0.2.1 install (2026-11-07)

- **sysusers warns about root** at every boot and during install:
  `/usr/lib/sysusers.d/basic.conf:10: Conflict with earlier configuration
  for user 'root' in /usr/lib/sysusers.d/00-bunix-root.conf:3`.  bunix's own
  root entry and systemd's default both define root.  Harmless, but noisy.
- **A session bus cannot drop groups**: `dbus-daemon: Failed to drop
  supplementary groups: Operation not permitted`.  Probably harmless; check
  which user's bus it is.
- **systemd-pcrextend: Could not extend NvPCR** at boot.  A TPM feature
  bunix does not set up yet; harmless.
- The user also noticed "some quirks" in daily use, not yet written down.

## Seen in QEMU

- **alsa-restore loops on machines without sound cards**: "Sound card
  volumes skipped" every 10 seconds in the journal, and "not starting since
  we tried this too often".  The unit is upheld by multi-user.target.

# Known issues

Small problems seen on real installs, to fix when there is time.  Newest
first; remove an entry when it is fixed.

## Buna Browser, first test in QEMU (2026-11-07)

- **The first-run screen still shows** ("The browser that gets more done",
  "Set Chromium as your default browser"), although initial_preferences
  sets `skip_first_run_ui` and `suppress_first_run_default_browser_prompt`.
  Check that Chromium reads /usr/lib/buna-browser/initial_preferences, or
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

- **An empty Hyprland config after a power cut.** Hyprland writes a new
  user's `~/.config/hypr/hyprland.lua` at the first login without syncing
  it; cutting the power right after (as tools/boot-test.py does when it
  stops the VM) leaves an empty file, and every later session has no key
  bindings.  Fix: write the default config ourselves (or sync it) when the
  account is made.
- **alsa-restore loops on machines without sound cards**: "Sound card
  volumes skipped" every 10 seconds in the journal, and "not starting since
  we tried this too often".  The unit is upheld by multi-user.target.

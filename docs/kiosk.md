# buna-kiosk: our own kiosk compositor

Status: design (2026-11-06), reviewed; nothing built.  Today the login
screen runs in cage (base/cage.bst, on wlroots).

## The goal

A small Wayland compositor, in Rust, that shows one app full screen and
nothing else, on top of **aquamarine**, the C++ library Hyprland uses for
screens and input:

- the login screen (buna-login), started by greetd, as cage does today;
- if decision 3 says so, the graphical first run of docs/desktop.md
  phase 6 (welcome, Wi-Fi, installer).

Not: windows side by side, workspaces, decorations, Xwayland, screen
sharing, plugins.

Words used below: an **output** is a screen as the compositor drives it;
the **app** is the one Wayland client (buna-login); its **window** is its
xdg toplevel with the popups and subsurfaces attached to it; the **seat
session** is libseat's hold on the screens and input devices (VT
switching), not the user's login session, which greetd starts afterwards.

## Decisions

1. **Build it at all**, against the other ways to run the login screen
   (next section).  The case for it is one display stack before and after
   login, under our own code; the price is about 10-14k lines to write and
   keep, on the most visible screen.
2. **The protocol layer**: the `wayland-server` crate (recommended) or
   libwayland-server inside the C++ shim.  The crate comes from the
   Smithay project but is not the Smithay compositor framework: it is the
   Rust counterpart of libwayland-server plus the protocols' generated
   types, and decides nothing for us.  libwayland-server in the shim
   would move the protocol code, the bulk of the work, into C++.
3. **The first run** (desktop.md phase 6): buna-kiosk, or Hyprland as a
   kiosk as desktop.md planned.  Recommended: buna-kiosk, once it runs
   the login screen; a first run in Hyprland needs its config locked down
   (no Super+Q, no workspaces), which a kiosk has by construction.

## Options considered

| Option | What it costs | Why (not) |
| --- | --- | --- |
| Keep cage | nothing; we maintain no compositor code | works today.  wlroots (85k lines of C) is in the system for it alone, and the screens and devices are driven by different code before and after login |
| Hyprland as the greeter | nothing to write; a locked-down config | one stack, but a full desktop compositor (its start-up, banners, config generation, the guiutils check) for one window: what 0.1.27 moved away from |
| Smithay's own backend (Rust: DRM, libseat, libinput, GBM) | the same protocol and renderer work; no C++ | no shim, no C++ ABI, no aquamarine API churn.  Not the same code as the desktop's, which is the point of this |
| **aquamarine + a C++ shim** (this design) | 10-14k lines (below) | the same DRM, input and session code as Hyprland: a screen or device quirk shows, and is fixed, the same way before and after login |

The user chose aquamarine over Smithay (2026-11-06).  What we trade:
today we maintain no compositor code and cage's upstream follows
wlroots' API changes; after the switch we maintain ~10-14k lines and
follow aquamarine's (also 0.x).

## What aquamarine gives, and what is left

aquamarine 0.16 is a *backend*, C++ only:

| aquamarine has | buna-kiosk adds |
| --- | --- |
| the seat session, through libseat (seatd or its logind backend); restoring outputs after a VT switch | stopping commits while the session is away; redrawing and re-applying modes when it returns |
| DRM/KMS outputs: modes, atomic commits, frame, present and state events, hotplug | which output shows the app; each output's swapchain (size, format, length), set up on every mode change |
| GBM buffers as dmabufs; its own small EGL context for format checks and multi-GPU copies | the renderer, with its own EGL context |
| input devices through libinput (recreated on every VT switch) | keymaps (xkbcommon), focus, touch, the cursor and the cursor plane's buffers |
| poll fds, each with its handler; a "poll fds changed" event | the event loop |

It has no Wayland server and no renderer: Hyprland has its own on top,
and buna-kiosk does the same, much smaller.

## The parts

```
 buna-login (GTK 4)                 greetd
      |  Wayland                       | starts it as "greeter"
 +----v--------------------------------v------------------------+
 | buna-kiosk (Rust)                                            |
 |  event loop: epoll over the client socket and the shim's fds |
 |  Wayland server (wayland-server crate)                       |
 |  window: the app's toplevel, popups, subsurfaces             |
 |  renderer: EGL + GLES 2                                      |
 |  input: one xkb state, focus, touch, cursor                  |
 +----|---------------------------------------------------------+
      | C ABI: opaque handles, one event queue
 +----v---------------------+
 | shim (C++, ~1-1.5k lines)|  owns every aquamarine object
 +----|---------------------+
      v
 aquamarine -> libseat, DRM, GBM, libinput
```

The Rust side is one `State` struct (outputs, the window, the seat, the
renderer), one file per protocol group (`compositor.rs`, `xdg.rs`,
`seat.rs`, `dmabuf.rs`, ...), and the window is a plain struct, not a
scene graph.

### The shim

aquamarine's API uses hyprutils' shared pointers, signals with
`std::function` listeners and STL types; Rust cannot call it.  The shim
is one C++ file, compiled by `build.rs`, that exposes a C API:

- **Ownership stays in C++.**  The shim holds every shared pointer and
  signal listener; Rust holds opaque handles (outputs, devices, buffers),
  valid until their "gone" event.
- **One event queue, no callbacks.**  aquamarine fires its signals inside
  the calls that cause them: new outputs inside `start()`, `commit` and
  sometimes `present` inside `output->commit()`, device add and remove
  inside the session's dispatch.  A Rust callback there would run while
  Rust is in the middle of changing its state.  So the shim's listeners
  only append a plain C struct (a tagged union) to a queue, and Rust
  drains it after every call into the shim:
  `aq_dispatch(fd); while (aq_next_event(&ev)) { match ev ... }`.  All
  event handling is one `match`.
- **No exception crosses.**  Every entry point catches (aquamarine uses
  `std::format`, which throws).

What it exposes, and nothing more:

| Calls | Events |
| --- | --- |
| create and start the backend; its poll fds; dispatch one fd | poll fds changed |
| per output: modes, enable or disable, set a mode, set up its swapchain, take the next buffer (a handle, and its dmabuf: fd, size, format, modifier, planes), commit, schedule a frame | new output, frame, needs frame, present, state (reconfigure), commit result, output gone |
| buffer handles stay the same while the swapchain does | buffer gone (the swapchain was reconfigured) |
| the render node fd, else the primary node fd | |
| cursor plane: its size, set a buffer, move, hide (phase 3b) | |
| | new device, device gone; key, pointer motion, button, axis, touch down, up, motion, frame |
| | seat session active or inactive |

The shim is the one place that calls aquamarine; Rust still follows its
model (swapchains, frame events, commit results).  A new aquamarine
version changes the shim, and Hyprland and buna-kiosk always build from
the same one.

### Leaving the screen lit

aquamarine turns every output off when its backend is destroyed (each
connector's `disconnect()` makes a blocking modeset that disables its
CRTC).  wlroots does the opposite on purpose ("leave CRTCs on when
shutting down"), and the boot as it is now depends on it: the login
screen stays on screen until Hyprland draws over it.  So buna-kiosk, when
the app has exited, closes its clients and exits the process without
destroying the backend: the kernel drops DRM master with the CRTCs still
lit, as after cage.  This is tested in phase 1.

### The Wayland server

The protocols, with the versions cage offers today where GTK depends on
them:

| Protocol | Why |
| --- | --- |
| wl_compositor v6, wl_subcompositor, wl_region | surfaces (v6: the preferred buffer scale); GTK uses subsurfaces |
| wl_shm | software-drawn buffers: GTK on llvmpipe, cursors |
| zwp_linux_dmabuf_v1 v4 | GPU buffers, GTK's normal path: a format table, the main device (the render node, else the primary node), feedback per surface |
| xdg_wm_base v5 | the toplevel, always full screen; popups (GTK's popovers use `reposition`, v3) |
| wl_seat v7+: keyboard (with repeat info), pointer, touch | input; its capabilities follow hotplug and VT switches (buna-login shows its keyboard button when there is touch) |
| wl_output v4 | the output's size, scale and name |

Later, each a step of its own: wp_viewporter and wp_fractional_scale_v1
(cage has neither, so today's login screen runs at scale 1; fractional
scale changes how it looks), wp_cursor_shape_v1, wp_presentation,
wp_single_pixel_buffer_v1.

Not needed, with the reason: xdg-decoration (full screen), layer-shell,
session-lock, screencopy; text-input and input-method (the on-screen
keyboard is inside buna-login); primary selection and data-device (GTK 4
handles its own copy and paste; checked by running without them);
explicit sync (bunix's GTK and Mesa use GL, not Vulkan, with implicit
sync).

The parts wlroots did for cage that are most of the work: synchronized
subsurface state, configure and ack before the first buffer, buffer
release and frame callbacks, popup placement (`xdg_positioner`
constraint adjustment, 500 lines in wlroots), popup grabs, the keymap
memfd, and flushing clients after every dispatch (forgetting it hangs the
app).

The app gets a socketpair (`WAYLAND_SOCKET`), not a named socket: no
other process can connect, and its exit is seen at once.

### The renderer

EGL with GBM on aquamarine's render node, or on the primary node where
there is none (QEMU's standard VGA, for one); OpenGL ES 2 through `glow`
(EGLImage functions loaded with `eglGetProcAddress` if glow lacks them).
Each swapchain buffer is imported once as an EGLImage and kept until its
"buffer gone" event; the app's dmabufs are imported the same way, shm
buffers uploaded as textures.  The window is drawn stretched to the
output, then the cursor.  On llvmpipe, `glFinish` before commit (no
implicit sync there).  Damage tracking only if measured to matter;
showing the app's buffer directly (scanout: the screen reads it without
a copy) later, if ever.

### Input

- **Keyboard**: one xkb state for all keyboards, from `XKB_DEFAULT_LAYOUT`
  and `XKB_DEFAULT_OPTIONS` as with cage (greetd's config: `us,ara`,
  Alt+Shift); the layout group goes to the app in `wl_keyboard.modifiers`.
  Reset when the seat session comes back, so Ctrl+Alt from Ctrl+Alt+F2
  are not stuck.  Ctrl+Alt+F1..F6 switch VTs through the session.
- **Touch** goes to the app as `wl_touch`, with `frame` events, on the
  output that shows it (libinput's output name for the touch screen; a
  touch screen on a black output does nothing).  Touch hides the cursor
  until the mouse moves.
- **Pointer and cursor**: the cursor drawn last into the frame at first;
  the hardware cursor plane (its own small swapchain, filled by
  buna-kiosk) in phase 3b.  `wl_pointer.set_cursor` with a surface, or
  null to hide it, as GTK sends.  bunix has no cursor theme: a built-in
  arrow and text cursor until it has one.

### Outputs

The app goes on one output and the others are disabled: an external one
if there is one (not eDP, LVDS or DSI), else the internal panel; as
`cage -m last` mostly does, but chosen, not left to connector order.
Each gets its preferred mode, at scale 1 until fractional scale comes.
On hybrid laptops an external monitor is often on the second GPU, which
aquamarine serves by copying frames between GPUs: the testbed has one
GPU, so this needs a second machine before phase 4.

### Running it

`greetd.toml` changes from `cage -m last -- buna-login` to
`buna-kiosk -- buna-login`: it starts the app, exits when the app exits
(greetd then starts the user's session), and exits non-zero when the app
cannot start.  greetd.service restarts it (`Restart=always`, every 3 s,
no limit): a crashing kiosk never fails the unit, so the boot would still
be marked good.  Hence a fallback for the first release (phase 4).

## Build

`src/buna-kiosk`, a cargo crate like buna-login:
`elements/base/buna-kiosk.bst` (kind `cargo`, crates vendored as `cargo2`
sources), depending on aquamarine, hyprutils, libdrm, libxkbcommon and
Mesa.  `build.rs` compiles the shim with the `cc` crate: `-std=c++23`
(aquamarine's headers need it), include paths from
`pkg-config aquamarine hyprutils libdrm`, linking libstdc++.  The shim
never includes `aquamarine/backend/Wayland.hpp` (it needs generated
headers aquamarine does not install).  It goes into the desktop
extension.

## Phases

Rough working time, given as a guide only: 1 week, 2 weeks, 3-4 weeks, 1
week.

1. **Pixels, VT switch, exit.**  The shim, and a binary that fills each
   output with the login screen's background on its `frame` events.
   Tests: a QEMU screenshot; Ctrl+Alt+F2 and back while it draws (commits
   cancelled, then resumed); exiting leaves the picture on screen (QEMU
   screenshot after exit; on the testbed, the splash -> kiosk -> console
   with no black between).
2. **One app.**  The Wayland server with shm, xdg-shell, the seat with a
   keyboard; GLES rendering.  Runs nested too: aquamarine's Wayland
   backend puts it in a Hyprland window, which makes the protocol work
   quick to try.  Test: buna-login shows and takes a typed password (QEMU,
   `BOOT_KEYS`).
3. **The login screen.**
   - 3a, one output: dmabuf, popups, subsurfaces, touch, pointer and
     cursor.  Tests: greetd runs buna-kiosk in QEMU and the
     desktop-install test logs in; a touch test with a uinput touch
     screen (the kernel has uinput; a helper in the test image) opens the
     on-screen keyboard.
   - 3b, several outputs: hotplug, the choice of output, the cursor
     plane.  Tested on hardware, and in QEMU with `virtio-vga,max_outputs=2`
     where the host allows it.
4. **The switch**, with a fallback: greetd starts a wrapper that runs
   buna-kiosk and, if it exits non-zero within a few seconds, cage.  One
   release later, if the fallback never ran: cage and wlroots leave the
   system.
5. **The first run**, if decision 3 says so.

What QEMU's standard VGA cannot test: dmabuf (GTK on llvmpipe sends shm),
the cursor plane, several outputs, multiple GPUs.  Those need the testbed
or `virtio-vga` runs.

## Risks

- **aquamarine's API** changes between versions (0.x, shaped by
  Hyprland).  The shim contains it; each bump goes through the QEMU login
  test first.
- **C++ ABI**: aquamarine depends on the C++ standard library's ABI.
  bunix builds everything with one toolchain, so they agree.
- **The protocol work** is most of the code, and its bugs show as an app
  that hangs or draws nothing.  `WAYLAND_DEBUG=1` traces, and running
  nested (phase 2), are the tools.
- **Hardware**: hybrid GPUs and odd panels go through code paths the
  testbed does not have; Hyprland's issue tracker is the reference, since
  it runs the same aquamarine.
- **The boot path**: a broken kiosk means no login screen (the root
  shells on Ctrl+Alt+F2-F6 stay).  The fallback in phase 4 covers the
  first release.

## Size

Not 6-9k lines, as a first draft said.  The wlroots code cage relies on
for these protocols, the GLES renderer and EGL is about 24k lines of C;
taking away what aquamarine covers and what one window makes unneeded
(outputs, scene graph, cursor, layout) leaves about 15k.  Hyprland's own
files for the same protocols are 5.6k lines of C++, without its surface
state, seat or renderer.  Estimate: 9-13k lines of Rust and a 1-1.5k-line
shim.

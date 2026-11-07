//! buna-kiosk: bunix's own kiosk compositor, on aquamarine (docs/kiosk.md).
//!
//! Phase 1: no app yet.  It takes the screens, fills each one with the login
//! screen's background, follows VT switches (Ctrl+Alt+F1..F12), and exits
//! leaving the picture lit.
//!
//!     buna-kiosk                      until it is stopped (SIGTERM)
//!     buna-kiosk --exit-after 30      for tests: exits after 30 seconds
mod aq;

use std::collections::HashMap;
use std::ffi::{c_int, c_ulong};
use std::process::ExitCode;
use std::time::{Duration, Instant};

use aq::{Aquamarine, Event};

/// The login screen's canvas, oklch(0.965 0.006 80) (src/buna-login/src/style.css)
const CANVAS: u32 = 0xf6f3ef;

// evdev key codes (linux/input-event-codes.h)
const KEY_LEFTCTRL: u32 = 29;
const KEY_RIGHTCTRL: u32 = 97;
const KEY_LEFTALT: u32 = 56;
const KEY_RIGHTALT: u32 = 100;
const KEY_F1: u32 = 59;
const KEY_F10: u32 = 68;
const KEY_F11: u32 = 87;
const KEY_F12: u32 = 88;

#[repr(C)]
struct PollFd {
    fd: c_int,
    events: i16,
    revents: i16,
}
const POLLIN: i16 = 0x1;
const POLLERR: i16 = 0x8;
const POLLHUP: i16 = 0x10;
const POLLNVAL: i16 = 0x20;

unsafe extern "C" {
    fn poll(fds: *mut PollFd, count: c_ulong, timeout_ms: c_int) -> c_int;
}

/// The VT a function key selects with Ctrl+Alt held, if it is one.
fn vt_of_function_key(code: u32) -> Option<u32> {
    match code {
        KEY_F1..=KEY_F10 => Some(code - KEY_F1 + 1),
        KEY_F11 => Some(11),
        KEY_F12 => Some(12),
        _ => None,
    }
}

/// Ctrl and Alt, held or not, to see Ctrl+Alt+Fn.
#[derive(Default)]
struct Modifiers {
    held: Vec<u32>,
}

impl Modifiers {
    fn track(&mut self, code: u32, pressed: bool) {
        let is_modifier = matches!(code, KEY_LEFTCTRL | KEY_RIGHTCTRL | KEY_LEFTALT | KEY_RIGHTALT);
        if !is_modifier {
            return;
        }
        self.held.retain(|&held| held != code);
        if pressed {
            self.held.push(code);
        }
    }

    fn ctrl_alt(&self) -> bool {
        let ctrl = self.held.contains(&KEY_LEFTCTRL) || self.held.contains(&KEY_RIGHTCTRL);
        let alt = self.held.contains(&KEY_LEFTALT) || self.held.contains(&KEY_RIGHTALT);
        ctrl && alt
    }

    /// After a VT switch the keys released on the other VT never arrive here.
    fn forget(&mut self) {
        self.held.clear();
    }
}

/// What an output still needs before it shows the canvas.
#[derive(Clone, Copy)]
struct Screen {
    /// Its mode is to be set (new, lost its mode, or back from another VT).
    needs_mode: bool,
    /// The next frame must draw it.
    dirty: bool,
}

struct Compositor {
    aquamarine: Aquamarine,
    screens: HashMap<u32, Screen>,
    modifiers: Modifiers,
}

impl Compositor {
    /// Brings every screen up to date: sets the modes it needs, draws what
    /// is dirty.  Nothing while another VT owns the screens: what is
    /// pending waits for this VT to come back.
    fn update(&mut self) {
        if !self.aquamarine.session_active() {
            return;
        }
        let outputs: Vec<u32> = self.screens.keys().copied().collect();
        for output in outputs {
            self.update_screen(output);
        }
    }

    fn update_screen(&mut self, output: u32) {
        let Some(mut screen) = self.screens.get(&output).copied() else { return };
        let name = self.aquamarine.output_name(output);
        if screen.needs_mode {
            let Some((width, height)) = self.aquamarine.enable_output(output) else {
                eprintln!("buna-kiosk: cannot turn on {name}");
                return;
            };
            eprintln!("buna-kiosk: {name}: {width}x{height}");
            screen.needs_mode = false;
            screen.dirty = true;
        }
        // A failed fill stays dirty, and asks for a frame to try again on
        if screen.dirty {
            let filled = self.aquamarine.fill_output(output, CANVAS);
            if filled {
                screen.dirty = false;
            } else {
                eprintln!("buna-kiosk: drawing on {name} failed; trying again on the next frame");
                self.aquamarine.schedule_frame(output);
            }
        }
        self.screens.insert(output, screen);
    }

    fn handle(&mut self, event: Event) {
        match event {
            Event::NewOutput(output) => {
                self.screens.insert(output, Screen { needs_mode: true, dirty: true });
            }
            Event::OutputGone(output) => {
                self.screens.remove(&output);
            }
            // one colour does not change: a frame draws only what is dirty
            Event::OutputFrame(_) => {}
            Event::OutputReconfigure(output) => {
                if let Some(screen) = self.screens.get_mut(&output) {
                    screen.needs_mode = true;
                }
            }
            Event::Key { code, pressed } => self.key(code, pressed),
            Event::SessionInactive => self.modifiers.forget(),
            // aquamarine restores the screens as they were: set the modes
            // again, once each, and draw
            Event::SessionActive => {
                for screen in self.screens.values_mut() {
                    screen.needs_mode = true;
                }
            }
        }
    }

    fn key(&mut self, code: u32, pressed: bool) {
        self.modifiers.track(code, pressed);
        let Some(vt) = vt_of_function_key(code) else { return };
        let switches_vt = pressed && self.modifiers.ctrl_alt();
        if switches_vt && !self.aquamarine.switch_vt(vt) {
            eprintln!("buna-kiosk: cannot switch to VT {vt}");
        }
    }

    fn handle_events(&mut self) {
        while let Some(event) = self.aquamarine.next_event() {
            self.handle(event);
        }
        self.update();
    }
}

fn parse_exit_after(args: &[String]) -> Result<Option<Duration>, String> {
    match args {
        [] => Ok(None),
        [flag, seconds] if flag == "--exit-after" => {
            let seconds: u64 = seconds.parse().map_err(|_| format!("not a number of seconds: {seconds}"))?;
            Ok(Some(Duration::from_secs(seconds)))
        }
        _ => Err("usage: buna-kiosk [--exit-after SECONDS]".to_string()),
    }
}

/// poll()'s timeout until the deadline: -1 (none) without one.
fn timeout_ms(deadline: Option<Instant>) -> c_int {
    let Some(deadline) = deadline else { return -1 };
    let left = deadline.saturating_duration_since(Instant::now());
    left.as_millis().min(c_int::MAX as u128) as c_int
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let exit_after = match parse_exit_after(&args) {
        Ok(exit_after) => exit_after,
        Err(message) => {
            eprintln!("{message}");
            return ExitCode::from(2);
        }
    };
    let deadline = exit_after.map(|duration| Instant::now() + duration);

    let Some(aquamarine) = Aquamarine::create() else {
        eprintln!("buna-kiosk: cannot open the screens (no DRM device, or no seat)");
        return ExitCode::FAILURE;
    };
    let mut compositor = Compositor { aquamarine, screens: HashMap::new(), modifiers: Modifiers::default() };
    if !compositor.aquamarine.start() {
        eprintln!("buna-kiosk: aquamarine did not start");
        return ExitCode::FAILURE;
    }
    compositor.handle_events();

    loop {
        let deadline_passed = deadline.is_some_and(|deadline| Instant::now() >= deadline);
        if deadline_passed {
            // Exits without destroying aquamarine's backend, which would turn
            // the screens off (docs/kiosk.md, "Leaving the screen lit")
            std::process::exit(0);
        }

        let mut fds: Vec<PollFd> = compositor
            .aquamarine
            .poll_fds()
            .into_iter()
            .map(|fd| PollFd { fd, events: POLLIN, revents: 0 })
            .collect();
        let ready = unsafe { poll(fds.as_mut_ptr(), fds.len() as c_ulong, timeout_ms(deadline)) };
        if ready < 0 {
            let error = std::io::Error::last_os_error();
            if error.kind() == std::io::ErrorKind::Interrupted {
                continue;
            }
            eprintln!("buna-kiosk: poll: {error}");
            return ExitCode::FAILURE;
        }

        for fd in &fds {
            // A hung-up or broken fd (seatd gone, say) would wake poll() at
            // once, forever: exit, and let greetd or systemd start a new one
            let is_broken = fd.revents & (POLLERR | POLLHUP | POLLNVAL) != 0;
            if is_broken {
                eprintln!("buna-kiosk: fd {} broke (poll revents {:#x})", fd.fd, fd.revents);
                return ExitCode::FAILURE;
            }
            if fd.revents & POLLIN != 0 {
                compositor.aquamarine.dispatch(fd.fd);
                compositor.handle_events();
            }
        }
    }
}

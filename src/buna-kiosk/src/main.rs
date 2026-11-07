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
use std::process::ExitCode;
use std::time::{Duration, Instant};

use aq::{Aquamarine, Event};

/// The login screen's canvas, oklch(0.965 0.006 80) (src/buna-login/src/style.css)
const CANVAS: u32 = 0xf6f3ef;

/// A screen that could not be turned on or drawn is tried again after this,
/// then after twice as long each time, up to RETRY_LONGEST.
const RETRY_FIRST: Duration = Duration::from_secs(1);
const RETRY_LONGEST: Duration = Duration::from_secs(30);

// evdev key codes (linux/input-event-codes.h)
const KEY_LEFTCTRL: u32 = 29;
const KEY_RIGHTCTRL: u32 = 97;
const KEY_LEFTALT: u32 = 56;
const KEY_RIGHTALT: u32 = 100;
const KEY_F1: u32 = 59;
const KEY_F10: u32 = 68;
const KEY_F11: u32 = 87;
const KEY_F12: u32 = 88;

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
    /// It is to be drawn.
    dirty: bool,
    /// The last try failed (logged once, until it works again).
    failing: bool,
}

impl Screen {
    fn pending(&self) -> bool {
        self.needs_mode || self.dirty
    }
}

/// When to try the failing screens again.
struct Retry {
    at: Option<Instant>,
    delay: Duration,
}

struct Compositor {
    aquamarine: Aquamarine,
    screens: HashMap<u32, Screen>,
    modifiers: Modifiers,
    retry: Retry,
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

        // Screens that failed are tried again later, on a timer that backs
        // off: a commit that keeps failing must not spin a CPU
        let any_pending = self.screens.values().any(|screen| screen.pending());
        if !any_pending {
            self.retry = Retry { at: None, delay: RETRY_FIRST };
        } else if self.retry.at.is_none() {
            self.retry.at = Some(Instant::now() + self.retry.delay);
            self.retry.delay = (self.retry.delay * 2).min(RETRY_LONGEST);
        }
    }

    fn update_screen(&mut self, output: u32) {
        let Some(mut screen) = self.screens.get(&output).copied() else { return };
        let name = self.aquamarine.output_name(output);

        if screen.needs_mode {
            match self.aquamarine.enable_output(output) {
                Some((width, height)) => {
                    eprintln!("buna-kiosk: {name}: {width}x{height}");
                    screen.needs_mode = false;
                    screen.dirty = true;
                }
                None if !screen.failing => eprintln!("buna-kiosk: cannot turn on {name}; trying again"),
                None => {}
            }
        }
        let can_draw = screen.dirty && !screen.needs_mode;
        if can_draw {
            let filled = self.aquamarine.fill_output(output, CANVAS);
            if filled {
                screen.dirty = false;
            } else if !screen.failing {
                eprintln!("buna-kiosk: drawing on {name} failed; trying again");
            }
        }
        screen.failing = screen.pending();
        self.screens.insert(output, screen);
    }

    fn handle(&mut self, event: Event) {
        match event {
            Event::NewOutput(output) => {
                self.screens.insert(output, Screen { needs_mode: true, dirty: true, failing: false });
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

    /// Runs until the deadline (None: forever), or until aquamarine breaks.
    fn run(&mut self, deadline: Option<Instant>) -> Result<(), String> {
        self.handle_events();
        loop {
            let now = Instant::now();
            if deadline.is_some_and(|deadline| now >= deadline) {
                return Ok(());
            }
            let retry_due = self.retry.at.is_some_and(|at| now >= at);
            if retry_due {
                self.retry.at = None;
                self.update();
            }

            let wake_at = [deadline, self.retry.at].into_iter().flatten().min();
            let timeout = wake_at.map(|at| at.saturating_duration_since(Instant::now()));
            self.aquamarine.wait(timeout)?;
            self.handle_events();
        }
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
    if !aquamarine.start() {
        eprintln!("buna-kiosk: aquamarine did not start");
        return ExitCode::FAILURE;
    }
    let mut compositor = Compositor {
        aquamarine,
        screens: HashMap::new(),
        modifiers: Modifiers::default(),
        retry: Retry { at: None, delay: RETRY_FIRST },
    };
    match compositor.run(deadline) {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("buna-kiosk: {message}");
            ExitCode::FAILURE
        }
    }
}

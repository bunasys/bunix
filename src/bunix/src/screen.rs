//! What a person sees: a few plain lines, and one bar that moves.
//!
//! On a terminal the bar is drawn over itself and has bunix's colour;
//! into a file or a pipe (a log, a script) the same is said as lines,
//! one for every tenth of the way, and with no colour.
//!
//! Nothing here fails: what cannot be written (a pipe whose reader has
//! gone) is not, and the work it tells of goes on.

use std::io::{IsTerminal, Write};

const BAR_WIDTH: usize = 28;
/// bunix's accent
const CLAY: &str = "\x1b[38;5;173m";
const GREEN: &str = "\x1b[32m";
const RED: &str = "\x1b[31m";
const DIM: &str = "\x1b[2m";
const BOLD: &str = "\x1b[1m";
const PLAIN: &str = "\x1b[0m";

/// `text` in a colour, where colour is of use: on a terminal, for a person
/// who has not asked for none (NO_COLOR).
fn coloured(colour: &str, text: &str, is_a_terminal: bool) -> String {
    let wanted = is_a_terminal && std::env::var_os("NO_COLOR").is_none();
    if wanted { format!("{colour}{text}{PLAIN}") } else { text.to_string() }
}

fn on_screen(colour: &str, text: &str) -> String {
    coloured(colour, text, std::io::stdout().is_terminal())
}

/// A line as it is.
pub fn say(line: &str) {
    let _ = writeln!(std::io::stdout(), "{line}");
}

/// What is being done, above everything said about it.
pub fn heading(text: &str) {
    say(&on_screen(BOLD, text));
}

/// Something worth knowing next, said aside.
pub fn aside(text: &str) {
    say(&format!("  {}", on_screen(DIM, text)));
}

/// It is done.
pub fn done(text: &str) {
    say(&format!("{} {text}", on_screen(GREEN, "✓")));
}

/// It is not, and why: a reason may be several lines.  Where errors go,
/// which may be a terminal when the rest is not.
pub fn failed(why: &str) {
    let mut errors = std::io::stderr();
    let cross = coloured(RED, "✗", errors.is_terminal());
    let mut lines = why.lines();
    let _ = writeln!(errors, "{cross} {}", lines.next().unwrap_or("It failed."));
    for line in lines {
        let _ = writeln!(errors, "  {line}");
    }
}

/// The bar: how far, in 100, and what is being done.
pub struct Bar {
    /// on a terminal: whether a bar is on the line the cursor is in
    is_drawn: bool,
    /// elsewhere: what the last line said, to say only what is news
    last_tenth: Option<u8>,
    last_doing: String,
}

impl Bar {
    pub fn new() -> Bar {
        Bar { is_drawn: false, last_tenth: None, last_doing: String::new() }
    }

    pub fn show(&mut self, percent: u8, doing: &str) {
        if std::io::stdout().is_terminal() {
            self.draw(percent, doing);
        } else {
            self.say_if_news(percent, doing);
        }
    }

    fn draw(&mut self, percent: u8, doing: &str) {
        let filled = BAR_WIDTH * percent.min(100) as usize / 100;
        let bar = format!("{}{}", on_screen(CLAY, &"█".repeat(filled)), on_screen(DIM, &"░".repeat(BAR_WIDTH - filled)));
        // \r: over the bar as it was; \x1b[K: and nothing left of a longer line
        let mut screen = std::io::stdout();
        let _ = write!(screen, "\r  {bar} {percent:>3}%  {}\x1b[K", on_screen(DIM, doing));
        let _ = screen.flush();
        self.is_drawn = true;
    }

    /// As lines: when it is doing something else, or is a tenth further.
    fn say_if_news(&mut self, percent: u8, doing: &str) {
        let tenth = percent / 10;
        let is_news = self.last_tenth != Some(tenth) || self.last_doing != doing;
        if !is_news {
            return;
        }
        say(&format!("  {percent:>3}%  {doing}"));
        self.last_tenth = Some(tenth);
        self.last_doing = doing.to_string();
    }

    /// Leaves the bar where it is, with what follows under it.
    pub fn finish(&mut self) {
        if self.is_drawn {
            say("");
            self.is_drawn = false;
        }
    }
}

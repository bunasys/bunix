//! bunix: what a person runs to look after their bunix system.
//!
//! It does nothing of its own to the system: updates are systemd-sysupdate's
//! and extensions systemd-sysext's, as docs/updates.md has them.  What is
//! here is the asking, in the order a person would have to know, and the
//! telling of what happens (sysupdate.rs, screen.rs).

mod ext;
mod screen;
mod sysupdate;
mod update;

use std::os::unix::process::CommandExt;
use std::process::{Command, ExitCode};

const USAGE: &str = "\
bunix: look after this bunix system

  bunix update              install the newest release
  bunix ext                 list the extensions, and which are on
  bunix ext enable <name>   turn one on: download it, and lay it over /usr
                            (it comes with the newest release, if this is not it)
";

fn main() -> ExitCode {
    let arguments: Vec<String> = std::env::args().skip(1).collect();
    match run(&arguments) {
        Ok(()) => ExitCode::SUCCESS,
        Err(why) => {
            screen::failed(&why);
            ExitCode::FAILURE
        }
    }
}

fn run(arguments: &[String]) -> Result<(), String> {
    let words: Vec<&str> = arguments.iter().map(String::as_str).collect();
    match words.as_slice() {
        ["update"] => {
            become_root(arguments)?;
            update::update()
        }
        ["ext"] | ["ext", "list"] => ext::list(),
        ["ext", "enable", name] => {
            become_root(arguments)?;
            ext::enable(name)
        }
        [] | ["help"] | ["--help"] | ["-h"] => {
            screen::say(USAGE.trim_end());
            Ok(())
        }
        _ => Err(format!("That is no command of bunix's.\n{USAGE}")),
    }
}

/// Comes back only as root.  For a person who is not, this program is
/// started again in its own place by run0, which asks them for their
/// password (polkit: a member of wheel).
fn become_root(arguments: &[String]) -> Result<(), String> {
    if runs_as_root() {
        return Ok(());
    }
    let this_program =
        std::env::current_exe().map_err(|error| format!("Cannot find this program's own file: {error}."))?;
    let mut run0 = Command::new("run0");
    // run0 starts a program with an environment of its own; a person's
    // wish for no colour is to go with it
    if std::env::var_os("NO_COLOR").is_some() {
        run0.arg("--setenv=NO_COLOR");
    }
    let not_started = run0.arg(this_program).args(arguments).exec();
    Err(format!("This changes the system, and run0 could not be started to ask for that: {not_started}."))
}

/// The standard library has no getuid: the kernel says who a process runs
/// as in /proc/self/status, "Uid:" and four numbers, the second the one
/// its rights are judged by.
fn runs_as_root() -> bool {
    let Ok(status) = std::fs::read_to_string("/proc/self/status") else {
        return false;
    };
    let effective_user = status
        .lines()
        .find_map(|line| line.strip_prefix("Uid:"))
        .and_then(|numbers| numbers.split_whitespace().nth(1));
    effective_user == Some("0")
}

//! `bunix ext`: the extensions of this system, and turning one on.
//!
//! An extension is an image systemd-sysext lays over /usr (developer
//! tools, say), built with each release for that release's /usr.  To
//! sysupdate it is a "feature": files of every release that a machine
//! downloads only if it is enabled there.  Enabling is a small file in
//! /etc; here that is done for a person, with the two steps that follow
//! it: the download, and having systemd lay the extension over /usr now.
//!
//! Three things can be true of one, each more than the one before:
//!
//!   enabled     the machine's choice, in /etc: updates bring it
//!   downloaded  its image for the running version is on the disk
//!   on          systemd has laid it over /usr: its programs are there

use crate::screen;
use crate::sysupdate;
use crate::update;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Where the system says which extensions there are: <name>.feature
const FEATURES: &str = "/usr/lib/sysupdate.d";
/// Where a machine's own choices are, over the system's
const CHOICES: &str = "/etc/sysupdate.d";
/// Where sysupdate keeps the images, each named with its version
/// (sysupdate.d/53-devtools.transfer)
const DOWNLOADED_TO: &str = "/var/lib/bunix/extensions";
/// What an extension that is laid over /usr has there, by systemd's rule
const MARK_OF_ONE_THAT_IS_ON: &str = "/usr/lib/extension-release.d/extension-release.";
/// Extensions with a login screen, which takes tty1 as it starts
/// (Conflicts=console-shell@tty1.service, nix/desktop/greetd.sh): the
/// shell there ends, with what runs in it.
const EXTENSIONS_WITH_A_LOGIN_SCREEN: &[&str] = &["desktop"];

struct Extension {
    name: String,
    description: String,
    is_enabled: bool,
}

impl Extension {
    fn is_on(&self) -> bool {
        Path::new(&format!("{MARK_OF_ONE_THAT_IS_ON}{}", self.name)).exists()
    }

    fn is_downloaded_for(&self, version: &str) -> bool {
        Path::new(DOWNLOADED_TO).join(format!("{}_{version}.raw", self.name)).exists()
    }
}

pub fn list() -> Result<(), String> {
    let extensions = extensions()?;
    if extensions.is_empty() {
        screen::say("This system has no extensions.");
        return Ok(());
    }
    let longest_name = extensions.iter().map(|extension| extension.name.len()).max().unwrap_or(0);
    for extension in &extensions {
        let state = match (extension.is_on(), extension.is_enabled) {
            (true, _) => "on",
            (false, true) => "enabled, not on yet",
            (false, false) => "off",
        };
        screen::say(&format!("  {:<longest_name$}  {state:<19}  {}", extension.name, extension.description));
    }
    screen::aside("bunix ext enable <name> turns one on.");
    Ok(())
}

/// An extension with a login screen is not enabled from tty1: the login
/// screen would end this command, and the shell it was typed in, before
/// either says how it went.  Asked before run0, which gives this program
/// a terminal of its own; `run0 bunix ...` typed on tty1 is not seen.
pub fn refuse_on_tty1(name: &str) -> Result<(), String> {
    let brings_a_login_screen = EXTENSIONS_WITH_A_LOGIN_SCREEN.contains(&name);
    let would_end_this_shell = brings_a_login_screen && runs_on_tty1();
    if !would_end_this_shell {
        return Ok(());
    }
    Err(format!(
        "{name} brings a login screen, which takes tty1 from this shell as it starts.\n\
         Enable it from tty2 (Ctrl+Alt+F2) or over SSH.\n\
         The login screen is for a person with a password; if there is none yet:\n\
         \x20 useradd -m -G wheel <name> && passwd <name>"
    ))
}

/// Its input, output or errors on tty1: any one is enough for the end of
/// the shell there to end this command too.
fn runs_on_tty1() -> bool {
    let tty1 = Path::new("/dev/tty1");
    ["/proc/self/fd/0", "/proc/self/fd/1", "/proc/self/fd/2"]
        .iter()
        .any(|stream| std::fs::read_link(stream).is_ok_and(|terminal| terminal == tty1))
}

pub fn enable(name: &str) -> Result<(), String> {
    let extensions = extensions()?;
    let Some(extension) = extensions.iter().find(|extension| extension.name == name) else {
        let known: Vec<&str> = extensions.iter().map(|extension| extension.name.as_str()).collect();
        return Err(format!("There is no extension named {name}.\nThere are: {}.", known.join(", ")));
    };
    if extension.is_on() {
        screen::done(&format!("{name} is on already."));
        return Ok(());
    }

    // Enabled, then downloaded.  If it cannot be downloaded, the machine
    // is left as it was: one that has enabled what no release has for it
    // finds no release complete, and would install none again.
    let running = sysupdate::running_version()?;
    let was_enabled_before = extension.is_enabled;
    write_choice_to_enable(name)?;
    let downloaded = download(extension, &running);
    if downloaded.is_err() && !was_enabled_before {
        remove_choice_to_enable(name);
    }
    match downloaded? {
        Downloaded::ForTheRunningVersion => turn_on(extension),
        Downloaded::WithANewerVersion(newer) => {
            screen::done(&format!("{name} is installed with bunix {newer}, beside {running}."));
            screen::aside("Both start at the next restart:  systemctl reboot");
            Ok(())
        }
    }
}

enum Downloaded {
    ForTheRunningVersion,
    /// An extension is of one version of the system, and sysupdate
    /// installs only the newest: where that is not the running one, the
    /// extension comes with all of it, and is on once that has started.
    WithANewerVersion(String),
}

fn download(extension: &Extension, running: &str) -> Result<Downloaded, String> {
    let name = &extension.name;
    let Some(to_install) = sysupdate::version_to_install()? else {
        if extension.is_downloaded_for(running) {
            return Ok(Downloaded::ForTheRunningVersion);
        }
        if sysupdate::newer_waits_for_restart() {
            return Err(format!(
                "{name} comes with the newer bunix that is installed already, and not with {running}.\n\
                 Restart first (systemctl reboot), then enable it."
            ));
        }
        return Err(format!("No release has {name} for bunix {running} on this machine."));
    };

    if to_install == running {
        screen::heading(&format!("Downloading {name}"));
        update::install_with_bar()?;
        return Ok(Downloaded::ForTheRunningVersion);
    }
    screen::heading(&format!("bunix {running} → {to_install}, with {name}"));
    screen::aside(&format!("{name} is made for one version, and {to_install} is the newest: it comes with that."));
    update::install_with_bar()?;
    Ok(Downloaded::WithANewerVersion(to_install))
}

fn turn_on(extension: &Extension) -> Result<(), String> {
    let name = &extension.name;
    // The unit, not `systemd-sysext refresh`: before it merges, it picks
    // the extensions of the version that runs (systemd-sysext.service.d).
    let restarted = Command::new("systemctl")
        .args(["restart", "systemd-sysext.service"])
        .status()
        .map_err(|error| format!("Cannot run systemctl: {error}."))?;
    if !restarted.success() || !extension.is_on() {
        return Err(format!(
            "{name} is downloaded, but systemd did not lay it over /usr.\n\
             What systemd says of it:  systemctl status systemd-sysext.service"
        ));
    }
    screen::done(&format!("{name} is on: {}", extension.description));
    Ok(())
}

/// Every extension the system knows, by name.
fn extensions() -> Result<Vec<Extension>, String> {
    let entries = std::fs::read_dir(FEATURES).map_err(|error| format!("Cannot read {FEATURES}: {error}."))?;
    let mut extensions = Vec::new();
    for entry in entries.flatten() {
        let file_name = entry.file_name().to_string_lossy().into_owned();
        let Some(name) = file_name.strip_suffix(".feature") else {
            continue;
        };
        let description = setting(name, "Description").unwrap_or_default();
        let is_enabled = match setting(name, "Enabled") {
            Some(value) => means_yes(&value),
            None => false,
        };
        extensions.push(Extension { name: name.to_string(), description, is_enabled });
    }
    extensions.sort_by(|one, other| one.name.cmp(&other.name));
    Ok(extensions)
}

/// What a feature's files say for `key`: the system's file, then the
/// machine's own in /etc/sysupdate.d/<name>.feature.d/, by name, the last
/// one to say it winning, as systemd reads them.  (Of the places systemd
/// reads, these are the two bunix uses.)
fn setting(name: &str, key: &str) -> Option<String> {
    let mut files = vec![Path::new(FEATURES).join(format!("{name}.feature"))];
    if let Ok(entries) = std::fs::read_dir(choice_directory(name)) {
        let mut own: Vec<PathBuf> = entries.flatten().map(|entry| entry.path()).collect();
        own.retain(|path| path.to_string_lossy().ends_with(".conf"));
        own.sort();
        files.extend(own);
    }

    let mut value = None;
    for file in files {
        let Ok(text) = std::fs::read_to_string(file) else {
            continue;
        };
        for line in text.lines() {
            let Some((line_key, line_value)) = line.split_once('=') else {
                continue;
            };
            if line_key.trim() == key {
                value = Some(line_value.trim().to_string());
            }
        }
    }
    value
}

/// As systemd reads a yes or no.
fn means_yes(value: &str) -> bool {
    matches!(value.to_ascii_lowercase().as_str(), "1" | "yes" | "y" | "true" | "t" | "on")
}

fn choice_directory(name: &str) -> PathBuf {
    Path::new(CHOICES).join(format!("{name}.feature.d"))
}

/// The machine's choice to have the extension, as its feature's file says
/// how.
fn write_choice_to_enable(name: &str) -> Result<(), String> {
    let directory = choice_directory(name);
    let choice = directory.join("enable.conf");
    std::fs::create_dir_all(&directory)
        .and_then(|()| std::fs::write(&choice, "[Feature]\nEnabled=true\n"))
        .map_err(|error| format!("Cannot write {}: {error}.", choice.display()))
}

/// (the directory only if nothing else is in it: remove_dir takes no
/// directory that has files)
fn remove_choice_to_enable(name: &str) {
    let directory = choice_directory(name);
    let _ = std::fs::remove_file(directory.join("enable.conf"));
    let _ = std::fs::remove_dir(directory);
}

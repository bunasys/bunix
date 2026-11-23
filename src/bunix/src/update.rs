//! `bunix update`: the newest release, installed, with a bar to watch.

use crate::screen::{self, Bar};
use crate::sysupdate::{self, Progress};

pub fn update() -> Result<(), String> {
    let running = sysupdate::running_version()?;
    let Some(to_install) = sysupdate::version_to_install()? else {
        if sysupdate::newer_waits_for_restart() {
            screen::done("A newer bunix is installed already.");
            screen::aside("It starts at the next restart:  systemctl reboot");
        } else {
            screen::done(&format!("bunix {running} is the newest there is."));
        }
        return Ok(());
    };

    // The running version, when only files of it are missing: an
    // extension that was asked for by hand, and never downloaded.
    let only_completes_this_version = to_install == running;
    if only_completes_this_version {
        screen::heading(&format!("bunix {running}: downloading what is missing of it"));
        install_with_bar()?;
        screen::done(&format!("bunix {running} has all of its files."));
        return Ok(());
    }

    screen::heading(&format!("bunix {running} → {to_install}"));
    install_with_bar()?;
    screen::done(&format!("bunix {to_install} is installed, beside {running}."));
    screen::aside("It starts at the next restart:  systemctl reboot");
    screen::aside(&format!("If it does not start, this machine goes back to {running} by itself."));
    Ok(())
}

/// Has sysupdate install what it found, and shows how far it is, under
/// the heading its caller has given.  `bunix ext enable` downloads an
/// extension by it too: to sysupdate that is the same.
pub fn install_with_bar() -> Result<(), String> {
    let mut bar = Bar::new();
    bar.show(0, "reading the release's list of files");
    let installed = sysupdate::install(|progress| match progress {
        Progress::Downloading { part, parts, percent } => {
            bar.show(percent, &format!("downloading, part {part} of {parts}"));
        }
        Progress::PuttingInPlace => bar.show(100, "putting it in place"),
    });
    bar.finish();
    installed
}

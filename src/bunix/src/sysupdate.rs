//! systemd-sysupdate, asked and listened to.
//!
//! It is what updates a bunix (docs/updates.md): it reads the signed list
//! of a release's files, downloads what this machine is to have of them,
//! checks each, and writes it where the next start finds it.  None of that
//! is done here.  What it prints while it works is for a log; what it
//! tells whoever started it, over a socket, is how far it is, and that is
//! what `install` hands on.

use std::io::Read;
use std::os::unix::net::UnixDatagram;
use std::process::{Child, Command, ExitStatus, Stdio};
use std::time::Duration;

const SYSUPDATE: &str = "/usr/lib/systemd/systemd-sysupdate";
/// How many of sysupdate's last lines a person is shown when it fails
/// for a reason not known here
const LAST_LINES_SHOWN: usize = 4;

/// How far an installation is, as sysupdate tells it.
pub enum Progress {
    /// Downloading: a file of how many, and how much of all of it, in 100.
    Downloading { part: usize, parts: usize, percent: u8 },
    /// All of it is there and checked, and is being put in place.
    PuttingInPlace,
}

/// The version this machine runs: what its /usr says it is, and what
/// sysupdate compares a release with.
pub fn running_version() -> Result<String, String> {
    let os_release = std::fs::read_to_string("/usr/lib/os-release")
        .map_err(|error| format!("Cannot read /usr/lib/os-release: {error}."))?;
    os_release
        .lines()
        .find_map(|line| line.strip_prefix("IMAGE_VERSION="))
        .map(|version| version.trim_matches('"').to_string())
        .ok_or_else(|| "/usr/lib/os-release does not say which version of bunix this is.".to_string())
}

/// The version sysupdate would install now, if there is one: a newer one,
/// or the running one's when files of it are missing (an extension just
/// asked for).
pub fn version_to_install() -> Result<Option<String>, String> {
    let answer = Command::new(SYSUPDATE)
        .args(["check-new", "--json=short"])
        .output()
        .map_err(|error| format!("Cannot run {SYSUPDATE}: {error}."))?;
    if !answer.status.success() {
        return Err(what_went_wrong(&String::from_utf8_lossy(&answer.stderr)));
    }
    // {"available":"0.4.2"}, or {"available":null}
    let answer = String::from_utf8_lossy(&answer.stdout);
    let version = answer
        .trim()
        .strip_prefix("{\"available\":\"")
        .and_then(|rest| rest.strip_suffix("\"}"))
        .map(str::to_string);
    Ok(version)
}

/// Whether a version newer than the running one is installed already, and
/// waits for a restart.
pub fn newer_waits_for_restart() -> bool {
    // `pending` answers by how it ends
    let asked = Command::new(SYSUPDATE).arg("pending").stdout(Stdio::null()).stderr(Stdio::null()).status();
    matches!(asked, Ok(status) if status.success())
}

/// Installs what version_to_install found, telling `on_progress` how far
/// it is.  Ok when all of it is in place; an Err says why not, for a
/// person, and then nothing of it is.
pub fn install(on_progress: impl FnMut(Progress)) -> Result<(), String> {
    // Where sysupdate sends word (sd_notify): a socket of this run's own.
    let socket_path = format!("/run/bunix-update-{}.socket", std::process::id());
    let _ = std::fs::remove_file(&socket_path);
    let installed = UnixDatagram::bind(&socket_path)
        .map_err(|error| format!("Cannot make {socket_path}: {error}."))
        .and_then(|progress_socket| run_and_listen(&progress_socket, &socket_path, on_progress));
    let _ = std::fs::remove_file(&socket_path);
    installed.map_err(|why| format!("{why}\nNothing was installed."))
}

fn run_and_listen(
    progress_socket: &UnixDatagram,
    socket_path: &str,
    on_progress: impl FnMut(Progress),
) -> Result<(), String> {
    let mut sysupdate = Command::new(SYSUPDATE)
        .arg("update")
        .env("NOTIFY_SOCKET", socket_path)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| format!("Cannot run {SYSUPDATE}: {error}."))?;
    // What it logs is kept for the case that it fails, and read as it
    // comes: a pipe nobody reads fills, and sysupdate would wait on it.
    let mut log_pipe = sysupdate.stderr.take().expect("stderr was asked for");
    let log_reader = std::thread::spawn(move || {
        let mut log = Vec::new();
        let _ = log_pipe.read_to_end(&mut log);
        String::from_utf8_lossy(&log).into_owned()
    });

    let ended = listen_until_it_ends(progress_socket, &mut sysupdate, on_progress);
    let log = log_reader.join().unwrap_or_default();
    match ended {
        Ok(status) if status.success() => Ok(()),
        Ok(_) => Err(what_went_wrong(&log)),
        Err(error) => Err(format!("Lost track of {SYSUPDATE}: {error}.")),
    }
}

fn listen_until_it_ends(
    progress_socket: &UnixDatagram,
    sysupdate: &mut Child,
    mut on_progress: impl FnMut(Progress),
) -> std::io::Result<ExitStatus> {
    // A short wait for each message, so that between two of them it is
    // noticed that sysupdate has ended.
    progress_socket.set_read_timeout(Some(Duration::from_millis(100)))?;
    let mut message = [0u8; 4096];
    loop {
        if let Ok(length) = progress_socket.recv(&mut message) {
            if let Some(progress) = progress_in(&String::from_utf8_lossy(&message[..length])) {
                on_progress(progress);
            }
            continue;
        }
        let Some(status) = sysupdate.try_wait()? else {
            continue;
        };
        // What it sent between the last wait and its end is still there.
        progress_socket.set_nonblocking(true)?;
        while let Ok(length) = progress_socket.recv(&mut message) {
            if let Some(progress) = progress_in(&String::from_utf8_lossy(&message[..length])) {
                on_progress(progress);
            }
        }
        return Ok(status);
    }
}

/// What one message of sysupdate's says: lines of NAME=value, of which
/// these are read (systemd's sysupdate.c sends them, one kind a message):
///
///   X_SYSUPDATE_PROGRESS=37            how much of all of it, in 100
///   X_SYSUPDATE_TRANSFERS_DONE=1       files it has finished
///   X_SYSUPDATE_TRANSFERS_LEFT=4       files it has not, the one it is at
///                                      among them
///
///   STATUS=Installing '0.4.2'.         all are there; it puts them in place
fn progress_in(message: &str) -> Option<Progress> {
    let value_of = |name: &str| message.lines().find_map(|line| line.strip_prefix(name));
    if value_of("STATUS=Installing ").is_some() {
        return Some(Progress::PuttingInPlace);
    }
    let percent: usize = value_of("X_SYSUPDATE_PROGRESS=")?.parse().ok()?;
    let done: usize = value_of("X_SYSUPDATE_TRANSFERS_DONE=")?.parse().ok()?;
    let left: usize = value_of("X_SYSUPDATE_TRANSFERS_LEFT=")?.parse().ok()?;
    let parts = done + left;
    Some(Progress::Downloading { part: (done + 1).min(parts), parts, percent: percent.min(100) as u8 })
}

/// Why sysupdate failed, for a person: the reasons that have one thing to
/// do about them are said as that; any other is sysupdate's own last
/// words.
fn what_went_wrong(log: &str) -> String {
    // The first that the log has is taken, so one that says more comes
    // before one that says less: a list signed by the wrong key before a
    // list that could not be verified at all.
    let known_reasons = [
        (
            "Best before marker indicates out-of-date",
            "The newest release is too old to be trusted: the list of its files was only good \
             until a day that has passed.  Nothing is wrong with this machine; a newer release \
             has to be published.",
        ),
        (
            "Signature verification failed",
            "The release's list of files is not signed by a key this system trusts.",
        ),
        ("cannot verify", "The release's list of files is not signed."),
        (
            "Could not resolve host",
            "The release could not be reached: its server's name could not be looked up.  Is the network up?",
        ),
        ("Couldn't connect to server", "The release could not be reached.  Is the network up?"),
        (
            "not live yet",
            "This machine's clock is behind the day the release was signed.  The network sets it \
             a moment after a start: try again.",
        ),
    ];
    for (said_by_sysupdate, reason) in known_reasons {
        if log.contains(said_by_sysupdate) {
            return reason.to_string();
        }
    }

    let lines: Vec<&str> = log.lines().filter(|line| !line.trim().is_empty()).collect();
    if lines.is_empty() {
        return "systemd-sysupdate failed, and said nothing.".to_string();
    }
    let first_shown = lines.len().saturating_sub(LAST_LINES_SHOWN);
    format!("systemd-sysupdate failed:\n{}", lines[first_shown..].join("\n"))
}

//! `bunix install`: a package, built on this machine and installed in
//! /usr/local.
//!
//! The llvm extension brings the recipes (nix/packages.nix), each a
//! directory: what the package is, where its source is and what that has
//! to hash to, and the script that builds it, which is the one bunix's
//! own builds run.  Here a recipe's source is downloaded and checked, the
//! extension's builder is run on it (/usr/lib/bunix/build-package, which
//! says what a build on a machine has), and what it made is put in
//! /usr/local, with a list of it kept for the next time.
//!
//! The build runs as root, as this does, and what it runs is the source
//! the recipe pins.  Nothing holds it to its own directories: a source
//! whose `make install` did not go where it was told would write as root.

use crate::screen::{self, Clock};
use std::fs::File;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::Duration;

/// Where the llvm extension has the recipes, a directory each
const RECIPES: &str = "/usr/share/bunix/packages";
const BUILDER: &str = "/usr/lib/bunix/build-package";
/// What is installed: a file a package (InstalledList)
const INSTALLED: &str = "/var/lib/bunix/installed";
/// Where an installation works: root's alone, as /var/tmp is not.  In a
/// directory anyone can write to, another user could put their own files
/// where root is about to build.
const WORK: &str = "/var/lib/bunix/work";
const LOGS: &str = "/var/log/bunix";
/// Where packages go.  The builder is told the same (its `prefix`).
const PREFIX: &str = "/usr/local";
/// How much of a failed build's log a person is shown
const LAST_LOG_LINES_SHOWN: usize = 15;
/// What an installed list says its version is while the files are being
/// put in place: an installation that was cut short is seen as that
const NOT_ALL_THERE: &str = "incomplete";

// ---- The recipes ---------------------------------------------------------------

struct Recipe {
    directory: PathBuf,
    name: String,
    version: String,
    description: String,
    url: String,
    sha256: String,
    /// other recipes, to be installed before this one
    needs: Vec<String>,
}

fn recipe_names() -> Result<Vec<String>, String> {
    let entries = match std::fs::read_dir(RECIPES) {
        Ok(entries) => entries,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            return Err("Packages are built with the llvm extension, which is not on.\n\
                        Turn it on first:  bunix ext enable llvm"
                .to_string());
        }
        Err(error) => return Err(format!("Cannot read {RECIPES}: {error}.")),
    };
    let mut names: Vec<String> =
        entries.flatten().map(|entry| entry.file_name().to_string_lossy().into_owned()).collect();
    names.sort();
    Ok(names)
}

/// A recipe, from its `about`: lines of key=value (nix/packages/recipes.sh).
/// Its name is its directory's.
fn read_recipe(name: &str) -> Result<Recipe, String> {
    let directory = Path::new(RECIPES).join(name);
    let about_file = directory.join("about");
    let about = std::fs::read_to_string(&about_file)
        .map_err(|error| format!("There is no recipe for {name} ({}: {error}).", about_file.display()))?;
    let value_of = |key: &str| {
        let prefix = format!("{key}=");
        about
            .lines()
            .find_map(|line| line.strip_prefix(&prefix))
            .map(str::to_string)
            .ok_or_else(|| format!("{} does not say the package's {key}.", about_file.display()))
    };
    Ok(Recipe {
        name: name.to_string(),
        version: value_of("version")?,
        description: value_of("description")?,
        url: value_of("url")?,
        sha256: value_of("sha256")?,
        needs: value_of("needs")?.split_whitespace().map(str::to_string).collect(),
        directory,
    })
}

/// That there is a recipe by this name: asked before a person is asked
/// for their password.
pub fn check_there_is(name: &str) -> Result<(), String> {
    let known = recipe_names()?;
    if known.iter().any(|known_name| known_name == name) {
        return Ok(());
    }
    Err(format!("There is no package named {name}.\nThere are: {}.", known.join(", ")))
}

// ---- The commands --------------------------------------------------------------

pub fn list() -> Result<(), String> {
    let mut recipes = Vec::new();
    for name in recipe_names()? {
        recipes.push(read_recipe(&name)?);
    }
    let longest_name = recipes.iter().map(|recipe| recipe.name.len()).max().unwrap_or(0);
    for recipe in &recipes {
        let state = match InstalledList::read(&recipe.name) {
            Some(list) if list.version == recipe.version => "installed".to_string(),
            Some(list) if list.version == NOT_ALL_THERE => "installed in part".to_string(),
            Some(list) => format!("installed: {}", list.version),
            None => String::new(),
        };
        // (plain lines, as `bunix ext` lists: a table is not said aside)
        screen::say(&format!(
            "  {:<longest_name$}  {:<10}  {:<21}  {}",
            recipe.name, recipe.version, state, recipe.description
        ));
    }
    screen::aside("bunix install <name> builds one here, and installs it in /usr/local.");
    Ok(())
}

pub fn install(name: &str) -> Result<(), String> {
    check_there_is(name)?;
    let mut in_order = Vec::new();
    add_after_what_it_needs(name, &mut Vec::new(), &mut in_order)?;

    for recipe in &in_order {
        let is_installed = InstalledList::read(&recipe.name).is_some_and(|list| list.version == recipe.version);
        if !is_installed {
            install_one(recipe)?;
            continue;
        }
        let is_the_one_asked_for = recipe.name == name;
        if is_the_one_asked_for {
            screen::done(&format!("{} {} is installed already.", recipe.name, recipe.version));
        }
    }
    Ok(())
}

/// Adds the recipe to `in_order` after every recipe it needs, each once:
/// the order to install them in.  `led_here` is the recipes that needed
/// this one, to notice needs that go round in a ring.
fn add_after_what_it_needs(name: &str, led_here: &mut Vec<String>, in_order: &mut Vec<Recipe>) -> Result<(), String> {
    if in_order.iter().any(|added| added.name == name) {
        return Ok(());
    }
    if led_here.iter().any(|earlier| earlier == name) {
        return Err(format!("The recipes need each other in a ring: {} → {name}.", led_here.join(" → ")));
    }
    let recipe = read_recipe(name)?;
    led_here.push(name.to_string());
    for needed in &recipe.needs {
        add_after_what_it_needs(needed, led_here, in_order)?;
    }
    led_here.pop();
    in_order.push(recipe);
    Ok(())
}

// ---- One installation ----------------------------------------------------------

fn install_one(recipe: &Recipe) -> Result<(), String> {
    screen::heading(&format!("Installing {} {}", recipe.name, recipe.version));

    // All of one installation is in a directory of its own, emptied at
    // its start (one that was cut short may have left it) and at its end.
    let work = Path::new(WORK).join(&recipe.name);
    let _ = std::fs::remove_dir_all(&work);
    let outcome = make_work_directory(&work).and_then(|()| download_build_and_put_in_place(recipe, &work));
    let _ = std::fs::remove_dir_all(&work);
    outcome
}

/// WORK is closed to everyone but root, whatever it was; what is above
/// it is not this program's alone (the list of what is installed is
/// there, for anyone to read).
fn make_work_directory(work: &Path) -> Result<(), String> {
    let closed_to_others = std::fs::Permissions::from_mode(0o700);
    std::fs::create_dir_all(WORK)
        .and_then(|()| std::fs::set_permissions(WORK, closed_to_others))
        .and_then(|()| std::fs::create_dir(work))
        .map_err(|error| format!("Cannot make {}: {error}.", work.display()))
}

fn download_build_and_put_in_place(recipe: &Recipe, work: &Path) -> Result<(), String> {
    let name = &recipe.name;

    screen::step("downloading its source");
    let source = work.join("source");
    download(&recipe.url, &source)?;
    let downloaded_sha256 = sha256_of(&source)?;
    if downloaded_sha256 != recipe.sha256 {
        return Err(format!(
            "What {} gave is not the source the recipe was written for.\n\
             Its SHA-256 is {downloaded_sha256}, and the recipe pins {}.\n\
             Nothing was built.",
            recipe.url, recipe.sha256
        ));
    }

    let log = Path::new(LOGS).join(format!("install-{name}.log"));
    screen::step(&format!("building it (its log: {})", log.display()));
    let made = work.join("made");
    build(recipe, &source, &made, &work.join("build"), &log)?;

    screen::step(&format!("putting it in {PREFIX}"));
    let files = files_made_for_prefix(&made, &log)?;
    let earlier = InstalledList::read(name);
    refuse_to_overwrite_what_is_not_its_own(name, &files, earlier.as_ref())?;
    if let Some(earlier) = &earlier {
        earlier.remove_files();
    }
    // Listed before they are there, and as not all there: an installation
    // that is cut short here is then seen as that, and done again.
    InstalledList { version: NOT_ALL_THERE.to_string(), files: files.clone() }.write(name)?;
    copy_into_prefix(&made, &files)?;
    InstalledList { version: recipe.version.clone(), files: files.clone() }.write(name)?;

    let programs: Vec<String> =
        files.iter().filter(|file| file.starts_with("bin/")).map(|file| format!("{PREFIX}/{file}")).collect();
    if programs.is_empty() {
        screen::done(&format!("{name} {} is installed in {PREFIX}.", recipe.version));
    } else {
        screen::done(&format!("{name} {} is installed: {}", recipe.version, programs.join(", ")));
    }
    Ok(())
}

fn download(url: &str, to: &Path) -> Result<(), String> {
    // --fail: a page that says "not found" is not the source.  And not
    // for ever: a server that does not answer, or sends nothing for a
    // minute, ends it.
    let downloaded = Command::new("curl")
        .args(["--fail", "--silent", "--show-error", "--location", "--retry", "2"])
        .args(["--connect-timeout", "20", "--speed-limit", "1", "--speed-time", "60"])
        .arg("--output")
        .arg(to)
        .arg(url)
        .output()
        .map_err(|error| format!("Cannot run curl: {error}."))?;
    if downloaded.status.success() {
        return Ok(());
    }
    let said_by_curl = String::from_utf8_lossy(&downloaded.stderr);
    Err(format!("Could not download {url}.\n{}", said_by_curl.trim()))
}

fn sha256_of(file: &Path) -> Result<String, String> {
    let hashed = Command::new("sha256sum")
        .arg(file)
        .output()
        .map_err(|error| format!("Cannot run sha256sum: {error}."))?;
    // "<hash>  <file>"
    let answer = String::from_utf8_lossy(&hashed.stdout);
    match answer.split_whitespace().next() {
        Some(hash) if hashed.status.success() => Ok(hash.to_string()),
        _ => Err(format!("Could not hash {}.", file.display())),
    }
}

/// Runs the extension's builder, what it prints going to `log`, with a
/// clock for the person waiting.
fn build(recipe: &Recipe, source: &Path, made: &Path, build_directory: &Path, log: &Path) -> Result<(), String> {
    std::fs::create_dir_all(LOGS).map_err(|error| format!("Cannot make {LOGS}: {error}."))?;
    let cannot_log = |error: std::io::Error| format!("Cannot write {}: {error}.", log.display());
    let log_file = File::create(log).map_err(cannot_log)?;
    // what it prints and what it complains of, into the one file, in the
    // order they came
    let log_file_again = log_file.try_clone().map_err(cannot_log)?;

    let mut builder = Command::new(BUILDER)
        .arg(&recipe.directory)
        .arg(source)
        .arg(made)
        .arg(build_directory)
        .stdin(Stdio::null())
        .stdout(log_file)
        .stderr(log_file_again)
        .spawn()
        .map_err(|error| format!("Cannot run {BUILDER}: {error}."))?;

    let mut clock = Clock::new();
    let status = loop {
        match builder.try_wait() {
            Ok(Some(status)) => break status,
            Ok(None) => {}
            Err(error) => return Err(format!("Lost track of the build: {error}.")),
        }
        clock.show();
        std::thread::sleep(Duration::from_millis(250));
    };
    clock.finish();
    if status.success() {
        return Ok(());
    }
    Err(format!(
        "Building {} failed.  Nothing was installed.\nThe end of its log ({}):\n{}",
        recipe.name,
        log.display(),
        end_of(log)
    ))
}

fn end_of(log: &Path) -> String {
    let text = std::fs::read(log).unwrap_or_default();
    let text = String::from_utf8_lossy(&text);
    let lines: Vec<&str> = text.lines().collect();
    let first_shown = lines.len().saturating_sub(LAST_LOG_LINES_SHOWN);
    lines[first_shown..].join("\n")
}

/// What the builder made, as paths from the prefix.  It installs under
/// the prefix, inside the directory it was given; a build that put
/// anything elsewhere (/var, /etc) made something this cannot install.
fn files_made_for_prefix(made: &Path, log: &Path) -> Result<Vec<String>, String> {
    let prefix_in_made = PREFIX.trim_start_matches('/');
    let mut for_prefix = Vec::new();
    let mut elsewhere = Vec::new();
    for file in files_under(made)? {
        match file.strip_prefix(prefix_in_made).and_then(|rest| rest.strip_prefix('/')) {
            Some(from_prefix) => for_prefix.push(from_prefix.to_string()),
            None => elsewhere.push(format!("/{file}")),
        }
    }
    if !elsewhere.is_empty() {
        return Err(format!(
            "The build installs outside {PREFIX}, which bunix install cannot do:\n{}\nNothing was installed.",
            elsewhere.join("\n")
        ));
    }
    if for_prefix.is_empty() {
        return Err(format!("The build installed nothing under {PREFIX}.  Its log is {}.", log.display()));
    }
    Ok(for_prefix)
}

/// Every file and link under `directory`, by its path from there.
fn files_under(directory: &Path) -> Result<Vec<String>, String> {
    let mut files = Vec::new();
    let mut directories = vec![PathBuf::new()];
    while let Some(relative) = directories.pop() {
        let Ok(entries) = std::fs::read_dir(directory.join(&relative)) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = relative.join(entry.file_name());
            // (of the entry itself: a link to a directory is a link)
            let is_a_directory = entry.file_type().is_ok_and(|kind| kind.is_dir());
            if is_a_directory {
                directories.push(path);
                continue;
            }
            // the list of what is installed is lines of text
            match path.to_str() {
                Some(text) if !text.contains('\n') => files.push(text.to_string()),
                _ => return Err(format!("The build made a file whose name cannot be listed: {}", path.display())),
            }
        }
    }
    files.sort();
    Ok(files)
}

/// A file in /usr/local that this package did not put there is another
/// package's, or a person's own: it is not replaced without a word.
fn refuse_to_overwrite_what_is_not_its_own(
    name: &str,
    files: &[String],
    earlier: Option<&InstalledList>,
) -> Result<(), String> {
    let is_its_own = |file: &String| earlier.is_some_and(|list| list.files.contains(file));
    let is_there = |file: &String| Path::new(PREFIX).join(file).symlink_metadata().is_ok();
    let not_its_own: Vec<String> = files
        .iter()
        .filter(|file| is_there(file) && !is_its_own(file))
        .map(|file| format!("{PREFIX}/{file}"))
        .collect();
    if not_its_own.is_empty() {
        return Ok(());
    }
    Err(format!(
        "{name} would replace files in {PREFIX} that it did not install:\n{}\n\
         Nothing was installed.  Move them away, and install again.",
        not_its_own.join("\n")
    ))
}

/// Copies the files, each with the mode the build gave it, and makes the
/// directories they need.  Not `cp -a` of the whole tree: that gives
/// /usr/local's own directories the modes of the build's, and one who
/// had opened /usr/local/bin to a group would find it closed again.
fn copy_into_prefix(made: &Path, files: &[String]) -> Result<(), String> {
    let made_for_prefix = made.join(PREFIX.trim_start_matches('/'));
    for file in files {
        let from = made_for_prefix.join(file);
        let to = Path::new(PREFIX).join(file);
        let copied = make_directories_for(&to).and_then(|()| copy_file_or_link(&from, &to));
        copied.map_err(|error| format!("Could not put {} in place: {error}.", to.display()))?;
    }
    Ok(())
}

/// The directories above `file` that are not there, each one that a
/// person who is not root can look into: whatever this process's own
/// mask for new files is.
fn make_directories_for(file: &Path) -> std::io::Result<()> {
    let Some(directory) = file.parent() else {
        return Ok(());
    };
    if directory.exists() {
        return Ok(());
    }
    make_directories_for(directory)?;
    std::fs::create_dir(directory)?;
    std::fs::set_permissions(directory, std::fs::Permissions::from_mode(0o755))
}

fn copy_file_or_link(from: &Path, to: &Path) -> std::io::Result<()> {
    let is_a_link = from.symlink_metadata()?.file_type().is_symlink();
    if !is_a_link {
        // (copies the mode with the bytes)
        return std::fs::copy(from, to).map(|_bytes| ());
    }
    let _ = std::fs::remove_file(to);
    std::os::unix::fs::symlink(std::fs::read_link(from)?, to)
}

// ---- What is installed ---------------------------------------------------------

/// What one package has in /usr/local, as its file in INSTALLED says it:
/// a line "version=<version>", then a path a line, each from the prefix.
struct InstalledList {
    version: String,
    files: Vec<String>,
}

impl InstalledList {
    fn read(name: &str) -> Option<InstalledList> {
        let text = std::fs::read_to_string(Path::new(INSTALLED).join(name)).ok()?;
        let mut lines = text.lines();
        let version = lines.next()?.strip_prefix("version=")?.to_string();
        let files = lines.map(str::to_string).collect();
        Some(InstalledList { version, files })
    }

    fn write(&self, name: &str) -> Result<(), String> {
        let file = Path::new(INSTALLED).join(name);
        let text = format!("version={}\n{}\n", self.version, self.files.join("\n"));
        std::fs::create_dir_all(INSTALLED)
            .and_then(|()| std::fs::write(&file, text))
            .map_err(|error| format!("Cannot write {}: {error}.", file.display()))
    }

    /// For a newer version, which may not have all of these: none is to
    /// stay behind.  Only what is under the prefix: a path of the list
    /// that leads out of it is not this program's to remove.
    fn remove_files(&self) {
        for file in &self.files {
            let leads_out = file.starts_with('/') || file.split('/').any(|part| part == "..");
            if !leads_out {
                let _ = std::fs::remove_file(Path::new(PREFIX).join(file));
            }
        }
    }
}

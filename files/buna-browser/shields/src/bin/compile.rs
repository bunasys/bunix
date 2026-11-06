//! Compiles filter lists into one engine file for Buna Browser's Shields:
//!
//!   buna-shields-compile engine.dat easylist.txt easyprivacy.txt ...
//!
//! uBlock Origin's lists use a small preprocessor that adblock-rust reads
//! as comments: `!#include file` (a list of the same directory) and
//! `!#if <condition>` / `!#else` / `!#endif` (rules for some browsers
//! only).  Left to adblock-rust, both branches of every `!#if` would apply
//! -- Firefox-only, mobile-only and disabled (`!#if false`) rules
//! included -- so both are resolved here, as uBlock Origin in Chromium
//! would.  Parsing the lists takes seconds; loading the compiled file in
//! the browser takes milliseconds.

use adblock::Engine;
use adblock::lists::{FilterSet, ParseOptions};
use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let Some((output, lists)) = args.split_first() else {
        eprintln!("usage: buna-shields-compile <engine file> <filter list>...");
        return ExitCode::FAILURE;
    };

    let mut filter_set = FilterSet::new(false);
    for list in lists {
        let text = match read_with_includes(Path::new(list)) {
            Ok(text) => text,
            Err(error) => {
                eprintln!("{error}");
                return ExitCode::FAILURE;
            }
        };
        println!("{list}: {} lines", text.lines().count());
        filter_set.add_filter_list(text, ParseOptions::default());
    }

    let engine = Engine::new_with_filter_set(filter_set);
    let data = engine.serialize();
    if let Err(error) = std::fs::write(output, &data) {
        eprintln!("{output}: {error}");
        return ExitCode::FAILURE;
    }
    println!("{output}: {} bytes", data.len());
    ExitCode::SUCCESS
}

/// The `!#if` conditions that hold here: uBlock Origin's names for a
/// Chromium browser running uBlock Origin's syntax.  Every other name
/// (env_firefox, env_mobile, cap_html_filtering, false, ...) is false.
const TRUE_CONDITIONS: &[&str] = &["env_chromium", "ext_ublock"];

/// The list's text with its preprocessor resolved: the lines of `!#if`
/// branches that do not hold are left out, and every `!#include <file>` of
/// a branch that holds is replaced by that file's text (resolved the same
/// way).  Only files in the list's own directory are included, as uBlock
/// Origin does.
fn read_with_includes(path: &Path) -> std::io::Result<String> {
    let text = std::fs::read_to_string(path)
        .map_err(|error| std::io::Error::new(error.kind(), format!("{}: {error}", path.display())))?;
    let directory = path.parent().unwrap_or(Path::new("."));

    // One entry per open `!#if`: whether its current branch holds
    let mut branches: Vec<bool> = Vec::new();
    let mut result = String::with_capacity(text.len());
    for line in text.lines() {
        if let Some(condition) = line.strip_prefix("!#if ") {
            branches.push(holds(condition));
            continue;
        }
        if line.trim_end() == "!#else" {
            if let Some(branch) = branches.last_mut() {
                *branch = !*branch;
            }
            continue;
        }
        if line.trim_end() == "!#endif" {
            branches.pop();
            continue;
        }
        let is_active = branches.iter().all(|&branch| branch);
        if !is_active {
            continue;
        }

        let included = line.strip_prefix("!#include ").map(str::trim);
        let is_local_file = included.is_some_and(|name| !name.contains('/'));
        match included {
            Some(name) if is_local_file => result.push_str(&read_with_includes(&directory.join(name))?),
            _ => result.push_str(line),
        }
        result.push('\n');
    }
    Ok(result)
}

/// A condition as uBlock Origin writes them: names joined by `&&` and
/// `||` (`&&` binds tighter), each possibly negated with `!`.
fn holds(condition: &str) -> bool {
    condition.split("||").any(|all_of| {
        all_of.split("&&").all(|term| {
            let term = term.trim();
            match term.strip_prefix('!') {
                Some(name) => !TRUE_CONDITIONS.contains(&name.trim()),
                None => TRUE_CONDITIONS.contains(&term),
            }
        })
    })
}

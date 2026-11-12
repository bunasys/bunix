#!/usr/bin/env python3
"""Checks a new Chromium release before Hudhud moves to it, and writes a
report to review (docs/browser.md, "Chromium updates"):

    tools/chromium-update.py <old tarball> <new tarball> <ungoogled-chromium> <report.md>

Hudhud is built on ungoogled-chromium's patches and lists, but does not wait
for its releases.  For each new Chromium this finds what changed between the
two source tarballs and, in what changed:

- Google addresses (ungoogled-chromium's own patterns, domain_regex.list) in
  files its domain substitution does not cover: they would reach Google;
- Google addresses in the files Hudhud keeps unsubstituted on purpose
  (files/hudhud/ungoogled/not-substituted.list): each must be one Hudhud
  means to reach;
- new prebuilt binaries its pruning list does not remove;
- ungoogled-chromium's patches that no longer apply;
- the release's commits whose subjects name Google services, from
  Chromium's log.

Hudhud's own patches are not checked here: files/hudhud/scripts/
prepare-source.sh on the new tree applies them all, and stops at the first
that fails.  Only the source is read; nothing is built.  Run with python3 -I.
"""

import difflib
import hashlib
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

old_tarball, new_tarball, ungoogled, report_path = sys.argv[1:5]
# absolute: patch runs in a temporary directory (failing_ungoogled_patches)
ungoogled = os.path.abspath(ungoogled)
repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEST_PATH = re.compile(r"(^|/)(test|tests|testing|testdata|test_data)/|"
                       r"_(unit|browser|ui|interactive_ui)?tests?\.|_fuzzer|/fuzz/")

# Commit subjects worth reading: features that may talk to Google
GOOGLE_SERVICE_WORDS = re.compile(
    r"google|gaia|sign.?in|sync|safe.?browsing|optimization.?guide|variations|"
    r"metrics|\buma\b|\bukm\b|crash|update|account|gemini|glic|lens|"
    r"privacy.?sandbox|component.?updater|telemetry|\bgcm\b|push", re.I)

# gitiles returns at most this many commits; more means a list cut short
COMMIT_LIMIT = 10000


def version_of(tarball):
    return re.search(r"chromium-([\d.]+)-lite", tarball).group(1)


def read_lines(path):
    with open(path, encoding="utf-8") as lines:
        return [line.strip() for line in lines if line.strip() and not line.startswith("#")]


def google_patterns():
    """The search half of each domain_regex.list line (before the #)."""
    lines = read_lines(os.path.join(ungoogled, "domain_regex.list"))
    return [re.compile(line.split("#")[0]) for line in lines]


def ungoogled_patches():
    """Paths of ungoogled-chromium's patches, in the order they apply."""
    names = read_lines(os.path.join(ungoogled, "patches", "series"))
    return [os.path.join(ungoogled, "patches", name) for name in names]


def patched_files(patch_path):
    with open(patch_path, encoding="utf-8", errors="replace") as patch:
        return [line[6:].split("\t")[0].strip()
                for line in patch if line.startswith("+++ b/")]


def tarball_files(tarball):
    """(path inside the tree, file object) for each regular file, in order."""
    with tarfile.open(tarball, "r|xz") as tar:
        for member in tar:
            if member.isfile():
                path = member.name.split("/", 1)[1]
                yield path, tar.extractfile(member)


def fingerprints(tarball):
    print(f"Reading {os.path.basename(tarball)} ...", file=sys.stderr)
    return {path: hashlib.sha256(content.read()).hexdigest()
            for path, content in tarball_files(tarball)}


def contents(tarball, wanted):
    print(f"Reading changed files from {os.path.basename(tarball)} ...", file=sys.stderr)
    return {path: content.read()
            for path, content in tarball_files(tarball) if path in wanted}


def is_binary(data):
    return b"\0" in data[:8192]


def added_lines(old_data, new_data):
    """The lines new_data has and old_data had not (all of them for a new file)."""
    new_lines = new_data.decode("utf-8", "replace").splitlines()
    if old_data is None:
        return new_lines
    old_lines = old_data.decode("utf-8", "replace").splitlines()
    return [line[1:] for line in difflib.unified_diff(old_lines, new_lines, n=0, lineterm="")
            if line.startswith("+") and not line.startswith("+++")]


def failing_ungoogled_patches(new_files):
    """Applies ungoogled-chromium's patches, in order, to the new release's
    copies of the files they touch; returns the ones that fail."""
    failed = []
    with tempfile.TemporaryDirectory() as tree:
        for path, data in new_files.items():
            os.makedirs(os.path.dirname(os.path.join(tree, path)) or tree, exist_ok=True)
            with open(os.path.join(tree, path), "wb") as out:
                out.write(data)
        for patch in ungoogled_patches():
            result = subprocess.run(["patch", "-p1", "--forward", "--silent", "-d", tree, "-i", patch],
                                    capture_output=True, text=True)
            if result.returncode != 0:
                output = (result.stdout + result.stderr).strip().splitlines()
                failed.append((os.path.relpath(patch, ungoogled), output[:3]))
    return failed


def release_commits(old_version, new_version):
    """Chromium's commits between the two releases (subject, short hash)."""
    url = (f"https://chromium.googlesource.com/chromium/src/+log/"
           f"{old_version}..{new_version}?format=JSON&n={COMMIT_LIMIT}")
    with urllib.request.urlopen(url, timeout=60) as response:
        text = response.read().decode("utf-8")
    log = json.loads(text[text.index("{"):])  # gitiles prefixes )]}'
    return [(entry["message"].splitlines()[0], entry["commit"][:10]) for entry in log["log"]]


def address_section(title, entries):
    lines = [f"## {title}", ""]
    for path, hits, count in entries:
        lines.append(f"- `{path}` ({count} new line{'s' if count != 1 else ''})")
        lines += [f"  - `{hit[:160]}`" for hit in hits]
    if not entries:
        lines.append("None.")
    return lines + [""]


def list_section(title, items):
    return [f"## {title}", ""] + (items or ["None."]) + [""]


old_version, new_version = version_of(old_tarball), version_of(new_tarball)
substituted = set(read_lines(os.path.join(ungoogled, "domain_substitution.list")))
pruned = set(read_lines(os.path.join(ungoogled, "pruning.list")))
kept_unsubstituted = set(read_lines(os.path.join(repo, "files/hudhud/ungoogled/not-substituted.list")))
patterns = google_patterns()

old_index = fingerprints(old_tarball)
new_index = fingerprints(new_tarball)
added = sorted(set(new_index) - set(old_index))
removed = sorted(set(old_index) - set(new_index))
changed = sorted(path for path in set(new_index) & set(old_index)
                 if new_index[path] != old_index[path])

files_ungoogled_patches = {path for patch in ungoogled_patches() for path in patched_files(patch)}
new_data = contents(new_tarball, set(added) | set(changed) | files_ungoogled_patches)
old_data = contents(old_tarball, set(changed))

# Google addresses in what this release added, by what happens to the file
# they are in
uncovered, kept, in_tests, covered = [], [], [], []
new_binaries = []
for path in added + changed:
    data = new_data[path]
    if is_binary(data):
        if path in added and path not in pruned:
            new_binaries.append(path)
        continue
    hits = [line.strip() for line in added_lines(old_data.get(path), data)
            if any(pattern.search(line) for pattern in patterns)]
    if not hits:
        continue
    entry = (path, hits[:5], len(hits))
    if path in kept_unsubstituted:
        kept.append(entry)
    elif path in substituted:
        covered.append(entry)
    elif TEST_PATH.search(path):
        in_tests.append(entry)
    else:
        uncovered.append(entry)

failed_patches = failing_ungoogled_patches(
    {path: data for path, data in new_data.items() if path in files_ungoogled_patches})

commits_note = None
try:
    commits = release_commits(old_version, new_version)
    if len(commits) >= COMMIT_LIMIT:
        commits_note = f"Chromium's log gave {COMMIT_LIMIT} commits, its limit: the list is cut short."
except Exception as error:  # the report is still useful without the log
    commits, commits_note = [], f"Chromium's log could not be read: {error}"
service_commits = [f"- [{commit}](https://chromium.googlesource.com/chromium/src/+/{commit}) {subject}"
                   for subject, commit in commits if GOOGLE_SERVICE_WORDS.search(subject)]

report = [
    f"# Chromium {old_version} → {new_version}",
    "",
    "Made by tools/chromium-update.py; read it before Hudhud moves to the new release.",
    "",
    "| | |",
    "| --- | --- |",
    f"| Files added / changed / removed | {len(added)} / {len(changed)} / {len(removed)} |",
    f"| Google addresses in files the substitution does not cover | **{len(uncovered)} files** |",
    f"| Google addresses in files Hudhud keeps unsubstituted (review each) | **{len(kept)} files** |",
    f"| New binaries the pruning list misses | **{len(new_binaries)}** |",
    f"| ungoogled-chromium patches that no longer apply | **{len(failed_patches)}** |",
    f"| Commits / naming a Google service | {len(commits)} / {len(service_commits)} |",
    f"| Google addresses in tests only / in files the substitution rewrites | {len(in_tests)} / {len(covered)} files |",
    "",
]
report += address_section("Google addresses not covered by the substitution", uncovered)
report += address_section("Google addresses in files Hudhud keeps unsubstituted", kept)
report += list_section("New binaries not pruned", [f"- `{path}`" for path in new_binaries])
report += list_section("ungoogled-chromium patches that no longer apply",
                       [f"- `{name}`: {' / '.join(output)}" for name, output in failed_patches])
report += list_section("Commits that name a Google service (to read)",
                       ([commits_note] if commits_note else []) + service_commits)
report += address_section("Google addresses in tests only", in_tests)
report += address_section("Google addresses in files the substitution rewrites", covered)
report += list_section("Removed files", [f"- `{path}`" for path in removed])

with open(report_path, "w", encoding="utf-8") as out:
    out.write("\n".join(report))

print(f"Wrote {report_path}: {len(uncovered)} uncovered, {len(kept)} kept unsubstituted, "
      f"{len(new_binaries)} new binaries, {len(failed_patches)} failing patches, "
      f"{len(service_commits)} commits to read")

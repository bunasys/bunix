#!/usr/bin/env python3
r"""bunix's dependencies: what each element is built from, and whether it is
out of date or has known vulnerabilities (docs/dependencies.md).

    tools/deps.py inventory [out]   one line per element: version, how it is tracked
    tools/deps.py check [out]       new releases and advisories, as Markdown
    tools/deps.py sbom [out]        CycloneDX software bill of materials

The elements are the database: each one's sources pin a URL and a sha256,
and the URL carries the version.  What they do not say is where each
project releases, so upstreams.yml (at the top of the repository) names it
for every element that downloads something.  It is a separate file because
BuildStream puts an element's public data in its cache key: keeping this
there would rebuild the system for every edit.

Each entry is tracked exactly one way:

    anitya: 5303                   release-monitoring.org project id
    github: gavinhoward/bc         the project's newest GitHub release
    follows: google/fonts@main     pinned to a commit of this branch
    part-of: base/dbus.bst         another copy of that element's project,
                                   meant to be on its version
    pinned-by: base/chromium.bst   pinned by that element's project, and
                                   moved with it (Crubit, by Chromium)
    untracked: <why>               replaced by hand

and may also have:

    cpe: a:zlib:zlib               NVD's part:vendor:product, for advisories:
                                   a for an application, o for an operating
                                   system; a list when NVD files them under
                                   several vendors
    debian: glib2.0                the project's Debian source package and
    alpine: glib                   Alpine package, for their advisories
    version-regex: LVM2\.([\d.]+)\.tgz
                                   one group: the version, read from the URL,
                                   when its file name does not say it plainly

Every command first checks that upstreams.yml and the elements agree, and
stops if they do not.

check asks release-monitoring.org (Anitya) or GitHub for new releases,
GitHub for new commits on followed branches, OSV.dev for advisories on the
Rust crates, Go modules and Python packages the elements vendor, NVD for
advisories by CPE, and Debian's and Alpine's security data by package.
Debian lists a CVE against a package when it is reported, NVD only once
it has analysed it, weeks later; Alpine lists the CVEs its updates fixed.  GITHUB_TOKEN and NVD_API_KEY are used when set
(NVD allows 5 requests in 30 seconds without a key, so a full check then
takes about 20 minutes).  Needs PyYAML: uv run --with pyyaml tools/deps.py.

The report is read by people and by an agent, and much of it comes from
outside: version strings are checked against a strict pattern before they
are written, and written as code.
"""

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
UPSTREAMS = REPO / "upstreams.yml"

TRACKING_KEYS = ("anitya", "github", "follows", "part-of", "pinned-by", "untracked")
ADVISORY_KEYS = ("cpe", "debian", "alpine")
OTHER_KEYS = ADVISORY_KEYS + ("version-regex",)

ARCHIVE_SUFFIX = re.compile(r"\.(tar\.(gz|xz|bz2|zst|lz)|tgz|tbz2|txz|zip|crate|deb|pem|ttf|otf)$")
COMMIT = re.compile(r"[0-9a-f]{40}")
SHA256 = re.compile(r"[0-9a-f]{64}")
# Where a version starts in a file name: after a separator (zlib-1.3.2,
# at-spi2-core-2.62.1, v258), or else right after letters (tzdata2026f,
# go1.25.3); it ends before anything that names a platform or how it is
# packed (go1.25.3.linux-amd64, chromium-157.0.8103.78-lite,
# swift-6.4.2-RELEASE-ubuntu24.04)
VERSION_AFTER_SEPARATOR = re.compile(r"(?:^|[-_])v?(\d.*)$")
VERSION_AFTER_LETTERS = re.compile(r"(?<=[A-Za-z])(\d.*)$")
PLATFORM_SUFFIX = re.compile(r"[-._](?:linux|x86_64|amd64|aarch64|arm64|src|source|unknown|lite|RELEASE).*$")
# What a version from outside may look like before it goes into the report
SAFE_VERSION = re.compile(r"[A-Za-z0-9][A-Za-z0-9._+~-]{0,63}")
CPE = re.compile(r"[aoh]:[a-z0-9_.\-]+:[a-z0-9_.+\-]+")
PACKAGE_NAME = re.compile(r"[a-z0-9][a-z0-9.+_-]*")
CVE_ID = re.compile(r"CVE-\d{4}-\d{4,}")
# A Debian or Alpine package version, as it may go into the report
DISTRIBUTION_VERSION = re.compile(r"[0-9][A-Za-z0-9.:+~_-]{0,63}")
# Debian's first package of a release: revision 1 (1~exp1 in experimental),
# 0.1 when not by its maintainer, none for a package of Debian's own
DEBIAN_FIRST_REVISION = re.compile(r"|1(~\S*)?|0\.1")


# --- The network -----------------------------------------------------------

def http_json(url, data=None, headers=None):
    """GET (or POST data) and decode JSON, waiting and retrying when the
    service says it is busy: NVD answers 403 when it is asked too often."""
    for attempt in range(4):
        request = urllib.request.Request(url, data=data, headers=headers or {})
        request.add_header("User-Agent", "bunix-deps (https://github.com/bunasys/bunix)")
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            is_busy = error.code in (403, 429, 502, 503, 504)
            if not is_busy or attempt == 3:
                raise
            time.sleep(int(error.headers.get("Retry-After") or 30 * (attempt + 1)))


def github_headers():
    token = os.environ.get("GITHUB_TOKEN")
    return {"Authorization": f"Bearer {token}"} if token else {}


# --- upstreams.yml and the elements ----------------------------------------

def load_upstreams():
    """upstreams.yml, every entry a dict and every cpe a list."""
    upstreams = yaml.safe_load(UPSTREAMS.read_text()) or {}
    for name, entry in upstreams.items():
        entry = entry or {}
        if isinstance(entry.get("cpe"), str):
            entry["cpe"] = [entry["cpe"]]
        upstreams[name] = entry
    return upstreams


def release_version(url, entry):
    """The version of the release an element downloads, from its URL: by the
    entry's version-regex when it has one, else from the file name; the
    commit, for an archive of a commit; None when the URL does not say."""
    regex = entry.get("version-regex")
    if regex:
        match = re.search(regex, url)
        return match.group(1) if match else None
    path = urllib.parse.unquote(url.split("?")[0])
    commit = COMMIT.search(path)
    if commit:
        return commit.group(0)
    name = ARCHIVE_SUFFIX.sub("", path.rstrip("/").rsplit("/", 1)[-1])
    match = VERSION_AFTER_SEPARATOR.search(name) or VERSION_AFTER_LETTERS.search(name)
    if not match:
        return None
    version = PLATFORM_SUFFIX.sub("", match.group(1))
    # SQLite names its files 3XXYYZZ for 3.XX.YY(.ZZ): 3540100 is the 3.54.1
    # its release notes and Anitya say
    if name.startswith("sqlite-autoconf-"):
        major, minor, patch, branch = version[0], int(version[1:3]), int(version[3:5]), int(version[5:7])
        version = f"{major}.{minor}.{patch}" + (f".{branch}" if branch else "")
    return version


def vendored_packages(source):
    """(ecosystem, name, version) for each package a source pins by name.
    A crate from a git repository is not crates.io's crate of that name:
    its ecosystem is the repository, which OSV does not know."""
    kind = source["kind"]
    if kind == "cargo2":
        packages = []
        for crate in source.get("ref") or []:
            ecosystem = "crates.io" if crate.get("kind", "registry") == "registry" else crate.get("repo", "git")
            packages.append((ecosystem, crate["name"], crate["version"]))
        return packages
    if kind == "pypi":
        file_name = source["ref"]["suffix"].rsplit("/", 1)[-1]
        version = ARCHIVE_SUFFIX.sub("", file_name[len(source["name"]) + 1:])
        return [("PyPI", source["name"], version)]
    url = source.get("url", "")
    if url.startswith("goproxy:") and url.endswith(".zip"):
        module, _, version = url[len("goproxy:"):].rpartition("/@v/")
        # the proxy's file layout writes capitals as !lowercase
        module = re.sub(r"!([a-z])", lambda match: match.group(1).upper(), module)
        return [("Go", module, version[:-len(".zip")])]
    return []


def read_elements(upstreams):
    """{element: {"version", "url", "sha256", "vendored"}} for every element
    that downloads something.  An element's release is its first source
    with a URL (or its container image); vendored packages are the crates,
    modules and Python packages its sources pin by name."""
    aliases = (yaml.safe_load((REPO / "project.conf").read_text()) or {}).get("aliases") or {}
    elements = {}
    for path in sorted((REPO / "elements").rglob("*.bst")):
        name = str(path.relative_to(REPO / "elements"))
        sources = (yaml.safe_load(path.read_text()) or {}).get("sources") or []
        release, vendored = None, []
        for source in sources:
            packages = vendored_packages(source)
            vendored += packages
            is_release = not packages and (source.get("url") or source["kind"] == "docker")
            if release is None and is_release:
                release = source
        if release is None and not vendored:
            continue

        entry = upstreams.get(name) or {}
        if release is None:
            # a Python package and nothing else
            _, package, version = vendored[0]
            url, sha256 = f"https://pypi.org/project/{package}/{version}/", None
        elif release["kind"] == "docker":
            url = f"docker:{release['image']}"
            version, sha256 = release.get("track"), release["ref"]
        else:
            alias, _, rest = release["url"].partition(":")
            url = aliases[alias] + rest if alias in aliases else release["url"]
            version, sha256 = release_version(url, entry), release.get("ref")
        elements[name] = {"version": version, "url": url, "vendored": vendored,
                          "sha256": sha256 if isinstance(sha256, str) and SHA256.fullmatch(sha256) else None}
    return elements


def disagreements(elements, upstreams):
    """What keeps upstreams.yml from describing the elements as they are."""
    problems = []
    for name in sorted(set(elements) - set(upstreams)):
        problems.append(f"{name}: downloads {elements[name]['url']} but is not in upstreams.yml")
    for name in sorted(set(upstreams) - set(elements)):
        problems.append(f"{name}: in upstreams.yml but downloads nothing (removed or renamed?)")
    for name in sorted(set(upstreams) & set(elements)):
        entry, version = upstreams[name], elements[name]["version"]
        ways = [key for key in TRACKING_KEYS if key in entry]
        unknown_keys = sorted(set(entry) - set(TRACKING_KEYS) - set(OTHER_KEYS))
        if len(ways) != 1:
            problems.append(f"{name}: needs exactly one of {', '.join(TRACKING_KEYS)}")
        if unknown_keys:
            problems.append(f"{name}: unknown keys {', '.join(unknown_keys)}")
        for key in ("part-of", "pinned-by"):
            if key in entry and entry[key] not in elements:
                problems.append(f"{name}: {key} {entry[key]}, which downloads nothing")
        regex = entry.get("version-regex")
        if regex and re.compile(regex).groups != 1:
            problems.append(f"{name}: version-regex needs exactly one group")
        needs_release = "anitya" in entry or "github" in entry
        if needs_release and not version:
            problems.append(f"{name}: no version in {elements[name]['url']} (add a version-regex)")
        if "follows" in entry and not (version and COMMIT.fullmatch(version)):
            problems.append(f"{name}: follows a branch, but its URL names no commit")
        for cpe in entry.get("cpe", []):
            if not CPE.fullmatch(cpe):
                problems.append(f"{name}: cpe {cpe} is not part:vendor:product")
        for key in ("debian", "alpine"):
            if key in entry and not PACKAGE_NAME.fullmatch(str(entry[key])):
                problems.append(f"{name}: {key} {entry[key]} is not a package name")
    return problems


# --- New releases ----------------------------------------------------------

def series(version):
    """What a release must share with ours to be a patch release of it: the
    first two numbers (1.3 of 1.3.2; 10.6 of OpenSSH's 10.6p1).  Dated
    releases (tzdata 2026f, firmware 20261019, wireless-regdb 2026.09.03)
    are refreshed data: each is a patch release of the one before."""
    if re.match(r"(19|20)\d\d", version):
        return "dated"
    match = re.match(r"\d+(?:\.\d+)?", version)
    return match.group(0) if match else version


def anitya_versions(project_id):
    """Anitya's stable versions of a project, newest first."""
    project = http_json(f"https://release-monitoring.org/api/project/{project_id}")
    return project.get("stable_versions") or project.get("versions") or []


def github_versions(repo):
    """A GitHub project's newest release, as a one-version list."""
    release = http_json(f"https://api.github.com/repos/{repo}/releases/latest", headers=github_headers())
    return [release["tag_name"].removeprefix("v")]


def release_findings(name, version, versions):
    """Findings for an element whose project released versions (newest
    first): the newest release of our own series, a patch, and a newer
    series, a feature release.  Both are reported: Go 1.26.11 is a fix
    that should not wait behind Go 1.27."""
    # Strings of another form are left out (Anitya's glibc has an old
    # fedora/glibc-2.12.90-6); only the newest one being such needs a look,
    # as it could hide a release
    if versions and not SAFE_VERSION.fullmatch(versions[0]):
        return [("failures", f"`{name}`: the newest version string is of an unexpected form; "
                             "the project's data needs a look")]
    versions = [v for v in versions if SAFE_VERSION.fullmatch(v)]
    # a dated release may be written 2026-10-20 here and 20261020 there
    if version not in versions and version.replace("-", "") in versions:
        version = version.replace("-", "")
    if version not in versions:
        return [("unknown", f"`{name}` `{version}`: not among the project's versions "
                            f"(newest `{'`, `'.join(versions[:3])}`): check the mapping")]
    newer = versions[:versions.index(version)]
    if not newer:
        return []
    findings = []
    same_series = [v for v in newer if series(v) == series(version)]
    if same_series:
        findings.append(("patch", f"`{name}` `{version}` → **`{same_series[0]}`**"))
    if series(newer[0]) != series(version):
        releases_note = f", {len(newer)} releases newer" if len(newer) > 1 else ""
        findings.append(("feature", f"`{name}` `{version}` → **`{newer[0]}`**{releases_note}"))
    return findings


def branch_findings(name, follows, pinned_commit):
    """Findings for an element pinned to a commit of a branch."""
    repo, _, branch = follows.partition("@")
    compare = http_json(f"https://api.github.com/repos/{repo}/compare/{pinned_commit}...{branch}",
                        headers=github_headers())
    # the comparison lists at most 250 commits: the branch's own head is asked for
    head = http_json(f"https://api.github.com/repos/{repo}/commits/{branch}", headers=github_headers())["sha"]
    if compare["status"] == "identical":
        return []
    if compare["status"] != "ahead":
        return [("behind", f"`{name}` `{pinned_commit[:10]}`: no longer on {follows} "
                           f"({compare['status']}); now `{head[:10]}`")]
    return [("behind", f"`{name}` `{pinned_commit[:10]}`: {follows} is {compare['ahead_by']} "
                       f"commits ahead, now `{head[:10]}`")]


# --- Advisories ------------------------------------------------------------

def osv_advisories(packages):
    """{(ecosystem, name, version): [advisory ids]} for the affected ones."""
    found = {}
    packages = sorted({package for package in packages if package[0] in ("crates.io", "Go", "PyPI")})
    for start in range(0, len(packages), 500):
        batch = packages[start:start + 500]
        queries = [{"package": {"ecosystem": ecosystem, "name": name}, "version": version}
                   for ecosystem, name, version in batch]
        answer = http_json("https://api.osv.dev/v1/querybatch",
                           data=json.dumps({"queries": queries}).encode(),
                           headers={"Content-Type": "application/json"})
        for package, result in zip(batch, answer["results"]):
            ids = [vulnerability["id"] for vulnerability in result.get("vulns") or []]
            if ids:
                found[package] = ids
    return found


def nvd_advisories(cpe, version):
    """The CVE ids NVD says affect this version of this product."""
    key = os.environ.get("NVD_API_KEY")
    headers = {"apiKey": key} if key else {}
    product = f"cpe:2.3:{cpe}"
    match = urllib.parse.quote(f"{product}:{version}")
    found, start = set(), 0
    while True:
        try:
            answer = http_json("https://services.nvd.nist.gov/rest/json/cves/2.0"
                               f"?virtualMatchString={match}&noRejected&startIndex={start}",
                               headers=headers)
        finally:
            # NVD's published limits: 50 requests in 30 seconds with a key, 5 without
            time.sleep(0.7 if key else 6.5)
        # NVD also matches CVEs where this product is only what the
        # vulnerable one runs on (Django on Python, Apache with OpenSSL):
        # only the ones that call this product itself vulnerable count
        for item in answer.get("vulnerabilities", []):
            cve_id = item["cve"]["id"]
            if CVE_ID.fullmatch(cve_id) and names_vulnerable(item["cve"], product):
                found.add(cve_id)
        start += answer["resultsPerPage"]
        if answer["resultsPerPage"] == 0 or start >= answer["totalResults"]:
            break
    return found


def names_vulnerable(cve, product):
    for configuration in cve.get("configurations", []):
        for node in configuration.get("nodes", []):
            for match in node.get("cpeMatch", []):
                if match["vulnerable"] and match["criteria"].startswith(product + ":"):
                    return True
    return False


def compare_versions(ours, theirs):
    """-1, 0 or 1, as dpkg orders versions.  A version is read as runs of
    text and of digits: digits compare as numbers, text character by
    character, where ~ comes before anything, even the end of the text
    (1.0~rc1 before 1.0), and letters before other signs."""
    def rank(character):
        if character == "~":
            return -1
        if character == "":
            return 0
        if character.isalpha():
            return ord(character)
        return ord(character) + 256

    while ours or theirs:
        our_text, our_digits, ours = re.match(r"(\D*)(\d*)(.*)", ours).groups()
        their_text, their_digits, theirs = re.match(r"(\D*)(\d*)(.*)", theirs).groups()
        for index in range(max(len(our_text), len(their_text))):
            our_rank = rank(our_text[index] if index < len(our_text) else "")
            their_rank = rank(their_text[index] if index < len(their_text) else "")
            if our_rank != their_rank:
                return -1 if our_rank < their_rank else 1
        our_number, their_number = int(our_digits or 0), int(their_digits or 0)
        if our_number != their_number:
            return -1 if our_number < their_number else 1
    return 0


def still_affected(release, fixed_release, fixed_by_patch):
    """Whether our release still has a flaw a distribution fixed in its
    package of fixed_release: with a newer release, or with its own patch
    to that one (then the release itself still has it)."""
    order = compare_versions(release, fixed_release)
    return order < 0 or (order == 0 and fixed_by_patch)


def comparable_release(version):
    """Our version as the distributions write the project's release:
    json-c's tag date (0.19-20260627) and Swift's -RELEASE are only in the
    archive's name."""
    return re.sub(r"-(\d{8}|RELEASE)$", "", version)


def fixed_note(distribution_version):
    """Where a distribution fixed a CVE, for the report: its package version
    says whether the fix came with a release or as its own patch, and in
    which series."""
    if not DISTRIBUTION_VERSION.fullmatch(distribution_version):
        return "fixed, in a version of an unexpected form"
    return f"fixed in {distribution_version}"


def debian_release(debian_version):
    """('1.3.2', '4') for '1:1.3.dfsg+really1.3.2-4': the project's release,
    without Debian's marks for a repacked or reverted archive, and Debian's
    revision of its package.  A snapshot's tail stays: ncurses'
    6.6+20251231 has patches 6.6 does not."""
    without_epoch = debian_version.split(":", 1)[-1]
    release, _, revision = without_epoch.rpartition("-")
    if not release:
        release, revision = without_epoch, ""
    release = release.split("+really")[-1]
    release = re.sub(r"[.+~](?:dfsg|ds|repack)\d*", "", release)
    return release, revision


def debian_advisories(cves, release):
    """[(CVE id, note)] from Debian's security tracker entries for one
    source package, by Debian's unstable release.  An open CVE is listed
    whatever our version: Debian may be behind us (glibc 2.43 to our 2.44)
    with the flaw in both."""
    found = []
    for cve_id, cve in cves.items():
        unstable = (cve.get("releases") or {}).get("sid") or {}
        is_relevant = CVE_ID.fullmatch(cve_id) and unstable.get("urgency") != "unimportant"
        if not is_relevant:
            continue
        if unstable.get("status") in ("open", "undetermined"):
            debian_has = next(iter((unstable.get("repositories") or {}).values()), "")
            has_readable_version = DISTRIBUTION_VERSION.fullmatch(debian_has)
            found.append((cve_id, f"open in {debian_has}" if has_readable_version else "open"))
            continue
        fixed_version = unstable.get("fixed_version") or ""
        # "0": Debian's package never had the flaw
        if fixed_version in ("", "0"):
            continue
        fixed_release, revision = debian_release(fixed_version)
        fixed_by_patch = not DEBIAN_FIRST_REVISION.fullmatch(revision)
        if still_affected(release, fixed_release, fixed_by_patch):
            found.append((cve_id, fixed_note(fixed_version)))
    return found


def alpine_release(alpine_version):
    """('10.6p2', 1) for '10.6_p2-r1': the project's release, with Alpine's
    suffixes written so that they order as upstream's (_p2 after the
    release, _rc1 before it), and Alpine's own release of its package."""
    release, separator, package_release = alpine_version.rpartition("-r")
    if not separator or not package_release.isdigit():
        release, package_release = alpine_version, "0"
    release = release.replace("_p", "p")
    release = re.sub(r"_(rc|pre|alpha|beta)", r"~\1", release)
    return release, int(package_release)


def alpine_advisories(secfixes, release):
    """[(CVE id, note)] from Alpine's security database entry for one
    package: the CVEs each of its package versions fixed.  Its release 1 or
    later of a project's release is its own patch to it."""
    found = []
    for fixed_version, entries in secfixes.items():
        # "0": Alpine's package never had the flaw
        if fixed_version == "0" or not isinstance(entries, list):
            continue
        fixed_release, package_release = alpine_release(fixed_version)
        if not still_affected(release, fixed_release, package_release > 0):
            continue
        for text in entries:
            found += [(cve_id, fixed_note(fixed_version)) for cve_id in CVE_ID.findall(str(text))]
    return found


def debian_tracker():
    """Debian's security tracker: {source package: {CVE id: ...}}, 90 MB."""
    return http_json("https://security-tracker.debian.org/tracker/data/json")


def alpine_secdb():
    """Alpine's security database: {package: secfixes}."""
    secdb = {}
    for repository in ("main", "community"):
        answer = http_json(f"https://secdb.alpinelinux.org/edge/{repository}.json")
        for package in answer["packages"]:
            secdb[package["pkg"]["name"]] = package["pkg"].get("secfixes") or {}
    return secdb


def year_and_number(cve_id):
    _, year, number = cve_id.split("-")
    return int(year), int(number)


def advisory_findings(name, version, entry, feeds):
    """[(section, line)]: the known vulnerabilities every source the entry
    names lists, merged by CVE, each with what its sources say about it.
    feeds holds the distributions' data that could be read, by key."""
    findings = []
    sources = {}  # CVE id: ["NVD", "Debian: fixed in 1.3.2-4", ...]

    def add(source, found):
        for cve_id, note in found:
            sources.setdefault(cve_id, []).append(f"{source}: {note}" if note else source)

    def failed(source, error):
        findings.append(("failures", f"`{name}`: {source}: {type(error).__name__}: {str(error)[:120]}"))

    for cpe in entry.get("cpe", []):
        try:
            add("NVD", [(cve_id, "") for cve_id in nvd_advisories(cpe, version)])
        except Exception as error:
            failed("NVD", error)

    # Both feeds list only packages that have had a CVE: a name they lack is
    # a clean package, or a wrong name
    release = comparable_release(version)
    unlisted = []
    debian_package = entry.get("debian")
    if debian_package and "debian" in feeds:
        if debian_package in feeds["debian"]:
            try:
                add("Debian", debian_advisories(feeds["debian"][debian_package], release))
            except Exception as error:
                failed("Debian", error)
        else:
            unlisted.append(f"Debian's `{debian_package}`")
    alpine_package = entry.get("alpine")
    if alpine_package and "alpine" in feeds:
        if alpine_package in feeds["alpine"]:
            try:
                add("Alpine", alpine_advisories(feeds["alpine"][alpine_package], release))
            except Exception as error:
                failed("Alpine", error)
        else:
            unlisted.append(f"Alpine's `{alpine_package}`")
    named_packages = [key for key in ("debian", "alpine") if key in entry]
    if not entry.get("cpe") and named_packages and len(unlisted) == len(named_packages):
        findings.append(("no-advisories", f"`{name}`: {' and '.join(unlisted)} never had one"))

    if not sources:
        return findings
    cves = sorted(sources, key=year_and_number, reverse=True)
    listed = [f"{cve_id} ({'; '.join(sorted(sources[cve_id]))})" for cve_id in cves[:10]]
    more_note = f" and {len(cves) - 10} more" if len(cves) > 10 else ""
    findings.append(("security", f"`{name}` `{version}`: {', '.join(listed)}{more_note}"))
    return findings


# --- check -----------------------------------------------------------------

REPORT_SECTIONS = {
    "security": "Known vulnerabilities",
    "patch": "Patch releases",
    "feature": "Feature releases",
    "behind": "Behind their branch",
    "drifted": "Not on the version of the element they are part of",
    "unknown": "Versions the project's releases do not list",
    "no-advisories": "No advisory source, or only ones that never listed the project",
    "failures": "Could not check",
}


def check_element(name, element, entry, elements, feeds):
    """[(section, line)] for one element.  Each check runs on its own, so
    one service failing leaves the others' findings."""
    version = element["version"]
    findings = []

    main = entry.get("part-of")
    main_version = elements[main]["version"] if main else None
    if main and version != main_version:
        findings.append(("drifted", f"`{name}` `{version}`, but `{main}` is `{main_version}`"))

    def run(label, check):
        try:
            findings.extend(check())
        except Exception as error:
            findings.append(("failures", f"`{name}`: {label}: {str(error)[:120]}"))

    if "anitya" in entry:
        run("Anitya", lambda: release_findings(name, version, anitya_versions(entry["anitya"])))
    elif "github" in entry:
        run("GitHub release", lambda: release_findings(name, version, github_versions(entry["github"])))
    elif "follows" in entry:
        run("GitHub branch", lambda: branch_findings(name, entry["follows"], version))

    is_tracked = any(key in entry for key in ("anitya", "github", "follows"))
    has_advisory_source = any(key in entry for key in ADVISORY_KEYS)
    if has_advisory_source and version:
        findings += advisory_findings(name, version, entry, feeds)
    elif is_tracked and not element["vendored"]:
        findings.append(("no-advisories", f"`{name}`"))
    return findings


def check(elements, upstreams):
    findings = []
    # Each distribution's data is read once; without it, its advisories are
    # reported missing and the rest of the check goes on.
    feeds = {}
    try:
        feeds["debian"] = debian_tracker()
    except Exception as error:
        findings.append(("failures", f"Debian's security tracker, for every element: {str(error)[:120]}"))
    try:
        feeds["alpine"] = alpine_secdb()
    except Exception as error:
        findings.append(("failures", f"Alpine's security database, for every element: {str(error)[:120]}"))
    vendored = [package for element in elements.values() for package in element["vendored"]]
    try:
        vendored_advisories = osv_advisories(vendored)
    except Exception as error:
        vendored_advisories = {}
        findings.append(("failures", f"OSV, for every vendored package: {str(error)[:120]}"))
    for name, element in elements.items():
        print(f"{name} ...", file=sys.stderr)
        findings += check_element(name, element, upstreams[name], elements, feeds)
        for package in element["vendored"]:
            if package in vendored_advisories:
                ecosystem, package_name, package_version = package
                findings.append(("security", f"`{name}` vendors {ecosystem} `{package_name}` "
                                             f"`{package_version}`: {', '.join(vendored_advisories[package])}"))
    return report(findings, len(elements), len(set(vendored)))


def report(findings, element_count, vendored_count):
    count = {section: sum(1 for kind, _ in findings if kind == section) for section in REPORT_SECTIONS}
    lines = [f"# bunix dependencies, {time.strftime('%Y-%m-%d')}", "",
             "Made by tools/deps.py check.", "",
             f"{element_count} elements, {vendored_count} vendored packages: {count['security']} "
             f"with advisories, {count['patch']} patch and {count['feature']} feature releases, "
             f"{count['behind']} behind their branch, {count['failures']} not checked.", "",
             "Each CVE names the sources that list it.  NVD lists a CVE only once it has "
             "analysed it, which can take weeks; Debian lists it when it is reported. "
             "\"Fixed in\": the distribution's first package version with the fix; a "
             "revision after its first package of a release (Debian's -2, Alpine's -r1) "
             "is its own patch.  \"Open in\": Debian's package has no fix yet.", ""]
    for section, title in REPORT_SECTIONS.items():
        section_lines = [f"- {line}" for kind, line in findings if kind == section]
        lines += [f"## {title}", ""] + (section_lines or ["None."]) + [""]
    return "\n".join(lines)


# --- inventory and sbom ----------------------------------------------------

def inventory(elements, upstreams):
    lines = []
    for name, element in elements.items():
        entry = upstreams[name]
        tracking = next(f"{key} {entry[key]}" for key in TRACKING_KEYS if key in entry)
        vendored_note = f"  +{len(element['vendored'])} vendored" if element["vendored"] else ""
        version = str(element["version"] or "-")[:20]
        lines.append(f"{name:42} {version:20} {tracking}{vendored_note}")
    return "\n".join(lines)


def sbom(elements, upstreams):
    """CycloneDX 1.6: one component per element, with its vendored packages
    as components of it."""
    purl_types = {"crates.io": "cargo", "Go": "golang", "PyPI": "pypi"}

    def vendored_component(package):
        ecosystem, name, version = package
        purl_type = purl_types.get(ecosystem)
        if purl_type:
            purl = f"pkg:{purl_type}/{name}@{version}"
        else:
            purl = f"pkg:generic/{name}@{version}?vcs_url={urllib.parse.quote(ecosystem, safe='')}"
        return {"type": "library", "name": name, "version": version, "purl": purl}

    components = []
    for name, element in elements.items():
        entry = upstreams[name]
        component = {"type": "library", "bom-ref": name, "name": name,
                     "externalReferences": [{"type": "distribution", "url": element["url"]}]}
        if element["version"]:
            component["version"] = element["version"]
        if element["sha256"]:
            component["hashes"] = [{"alg": "SHA-256", "content": element["sha256"]}]
        if entry.get("cpe") and element["version"]:
            # CycloneDX takes one CPE: the first is the project's main name
            component["cpe"] = f"cpe:2.3:{entry['cpe'][0]}:{element['version']}:*:*:*:*:*:*:*"
        if element["vendored"]:
            component["components"] = [vendored_component(package)
                                       for package in sorted(set(element["vendored"]))]
        components.append(component)
    return json.dumps({"bomFormat": "CycloneDX", "specVersion": "1.6", "version": 1,
                       "metadata": {"component": {"type": "operating-system", "name": "bunix"}},
                       "components": components}, indent=2)


def main():
    commands = {"inventory": inventory, "check": check, "sbom": sbom}
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command not in commands:
        sys.exit(__doc__)
    upstreams = load_upstreams()
    elements = read_elements(upstreams)
    problems = disagreements(elements, upstreams)
    if problems:
        sys.exit("upstreams.yml and the elements disagree:\n  " + "\n  ".join(problems))
    text = commands[command](elements, upstreams)
    if len(sys.argv) > 2:
        Path(sys.argv[2]).write_text(text + "\n")
    else:
        print(text)


if __name__ == "__main__":
    main()

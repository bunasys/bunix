# Keeping bunix's dependencies up to date

Status: step 1 runs: the check every day at 05:17 UTC
(.github/workflows/dependencies.yml), its report in the issue labelled
`dependencies`.  Steps 2–4 are design.  Agreed 2026-11-12.

## The goal

bunix builds about 230 projects from source, and vendors a few thousand
Rust crates, Go modules and Python packages inside them.  Each needs
watching for security fixes and new releases.  The process should be
autonomous where that is safe, secure against a compromised upstream or a
misleading changelog, and give the same answer twice for the same input.

## The parts

1. **The database is the elements.**  Each element's sources pin a URL and
   a sha256; the version is in the URL.  `upstreams.yml` (at the top of the
   repository) adds only what the elements do not say: where each project
   releases.  It is a separate file because BuildStream puts an element's
   `public:` data in its cache key, so keeping it there would rebuild the
   system on every edit.  `tools/deps.py` refuses to run when the two
   disagree, so neither can drift.

2. **A daily check, plain code.**  `tools/deps.py check` asks:
   - release-monitoring.org (Anitya) for new releases, and GitHub for new
     commits on branches an element follows;
   - OSV.dev for advisories on the vendored crates, Go modules and Python
     packages, by exact name and version;
   - for the rest, NVD by CPE, and Debian's security tracker and Alpine's
     security database by package name.  NVD lists a CVE against a
     product only once it has analysed it, which can take weeks; Debian
     lists it when it is reported, and says when no fix exists yet.

   It sorts what it finds into known vulnerabilities, patch releases (the
   newest of the series bunix is on), feature releases (a newer series),
   branches moved on, and elements of one project on different versions.
   `tools/deps.py sbom` writes the same inventory as a CycloneDX SBOM for
   each release.

3. **An agent per update** (a scheduled Claude cloud routine).  For each
   update it reads the changelog and the source diff between the two
   versions (as tools/chromium-update.py does for Chromium), updates the
   element, pushes an `update/<element>` branch and opens a pull request
   with a review report: new network endpoints, new prebuilt binaries,
   build-system and licence changes.

4. **Builds on pro13.**  pro13 runs a GitHub Actions self-hosted runner.
   It connects out to GitHub, so nothing on the home network is reachable
   from outside.  It builds the elements an `update/*` branch changes
   (tools/build-graph.py), with the shared cache, runs the boot tests, and
   reports on the pull request.  It builds only branches pushed to the
   repository, never pull requests from forks: the repository is public.

## Security

The agent reads text written by strangers (changelogs, release notes,
commit messages).  It is treated as data, never as instructions, and the
agent is given nothing that would make a mistake costly:

- a token that can push `update/*` branches and open pull requests, and
  nothing else: no push to main, no release, no signing keys;
- checks in plain code that it cannot talk its way past:
  - the sha256 the element pins is the one upstream publishes;
  - the release is signed by the key pinned in the repository for that
    project; a new key stops the update for a person to look at;
  - the release tarball matches the tagged commit (generated files aside),
    the check that would have caught the xz backdoor;
  - no new prebuilt binaries;
  - Fly and pro13 build the same output;
- a cooldown: a release is taken five days after it is published, unless it
  fixes a known vulnerability.  Most compromised or withdrawn releases were
  found within days.

## Who merges

At first, a person merges every pull request.  Once the review reports have
shown they can be trusted, pull requests for security fixes and patch
releases that pass every check and the boot tests merge on their own.
Feature releases always need a person.  Publishing a release of bunix stays
a person's decision.

## Batches

An update to glibc, LLVM, Rust or GTK rebuilds most of the system; these go
into one weekly batch with a full build.  Everything else, and every
security fix, goes daily.  Chromium keeps its own flow (docs/browser.md,
"Chromium updates").

## Order of work

1. `upstreams.yml`, `tools/deps.py` (inventory, check, SBOM), the daily
   check posting to a tracking issue.
2. Pinned signing keys, the tarball-vs-tag check, the cooldown.
3. The routine opening pull requests; the runner on pro13.
4. Merging security and patch updates on their own; weekly core batches.

## upstreams.yml

One entry per element that downloads something, tracked exactly one way
(tools/deps.py's docstring lists the keys).  Two choices in it need their
reasons:

- **part-of** and **pinned-by** are different.  A part is another copy of
  the same project (the bootstrap stages' gcc, glibc, ...) and should be on
  its main element's version: the check reports it when it is not.
  Something pinned by another element (Crubit and Chromium's Rust, by
  Chromium) moves with that element, on whatever version it pins.
- **Only an element's first downloaded source is tracked.**  Its other
  archives (a Zig program's dependencies, a font collection's files) are
  pinned by the project itself and move with it.  Vendored crates, Go
  modules and Python packages are checked for advisories one by one.

Advisories come from the sources an entry names: NVD for a `cpe`,
Debian and Alpine for a `debian` or `alpine` package.  The report lists
the tracked elements that have none of them and nothing vendored, and
those whose distribution packages never had an advisory (a clean package,
or a wrong name in upstreams.yml).

The distributions say which of their package versions fixed a CVE, not
which releases of the project have it.  The check reads it this way, and
the report shows the package version each verdict rests on:

- a fix in the distribution's package of a newer release: ours has the
  flaw;
- a fix in its later revision of our release (Debian's `-2`, Alpine's
  `-r1`): it patched a flaw our release has too.  Debian's first upload
  of a release is sometimes `-2`, which reads as a patch: the report's
  "fixed in" version shows it;
- a CVE Debian still has open: listed whatever our version, as Debian may
  be behind us with the flaw in both.

Some elements have no `debian` or `alpine` name on purpose: the kernel
and Chromium (Debian and Alpine are on other series or behind; NVD and
Chromium's own flow cover them), intel-microcode (Debian numbers it
differently), and projects the distributions package from another source
under the same name (Gavin Howard's bc, uutils' findutils).

Running it needs PyYAML:

    uv run --with pyyaml tools/deps.py inventory
    uv run --with pyyaml tools/deps.py check report.md
    uv run --with pyyaml tools/deps.py sbom bunix.cdx.json

`GITHUB_TOKEN` and `NVD_API_KEY` are used when set; without an NVD key a
full check takes about 20 minutes.

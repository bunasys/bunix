#!/usr/bin/env python3
"""Print the BuildStream sources for the Go modules a program needs.

    tools/go-modules.py <module dir> <package> [build tags]
    tools/go-modules.py ~/src/dux-shell-2.1.2/core ./cmd/dms withshell

Go builds offline in the sandbox from a module proxy laid out as files
(GOPROXY=file://...): each module's go.mod and source zip, at the paths
proxy.golang.org serves them from.  This finds which modules the package
needs on x86_64 Linux, by letting Go download them into an empty cache
here, and prints one `remote` source per file, with its sha256, to paste
under the element's `sources:`.  Go checks each zip against go.sum too.

Run it on the release the element's tarball pins, with Go on PATH at least
as new as its go.mod asks for.
"""

import hashlib
import os
import subprocess
import sys
import tempfile
from pathlib import Path


def is_missing_build_output(error):
    """A go:embed of files the build makes first (DMS embeds its UI, which
    `make` copies in): absent from a fresh checkout, and needs no module."""
    return "pattern " in error and "no matching files found" in error


def needed_module_files(module_dir, package, tags):
    """The proxy's .mod and .zip files the package needs, as (path, sha256)."""
    with tempfile.TemporaryDirectory() as cache:
        # The files must be the bytes the goproxy: alias serves, whatever
        # proxy, private modules or workspace this machine's Go is set to use
        env = dict(os.environ, GOMODCACHE=cache, GOOS="linux", GOARCH="amd64",
                   GOPROXY="https://proxy.golang.org", GOPRIVATE="", GONOPROXY="",
                   GOWORK="off", GOTOOLCHAIN="local",
                   # readonly, as in the sandbox: an untidy go.mod fails here,
                   # not later in the build
                   GOFLAGS="-mod=readonly -modcacherw")
        # Listing the package's dependencies downloads exactly the modules
        # that provide them, and the go.mod files Go reads to choose versions.
        # -e lists past the embed of build output; every other error stops us.
        listing = subprocess.run(
            ["go", "list", "-e", "-deps", "-tags", tags,
             "-f", "{{with .Error}}{{.}}{{end}}", package],
            cwd=module_dir, env=env, check=True, capture_output=True, text=True)
        errors = [line for line in listing.stdout.splitlines() if line]
        real_errors = [e for e in errors if not is_missing_build_output(e)]
        if real_errors:
            sys.exit("go list failed:\n" + "\n".join(real_errors))

        download = Path(cache, "cache", "download")
        files = []
        for path in sorted(download.rglob("*")):
            is_proxy_file = path.suffix in (".mod", ".zip") and path.parent.name == "@v"
            if is_proxy_file:
                sha256 = hashlib.sha256(path.read_bytes()).hexdigest()
                files.append((path.relative_to(download).as_posix(), sha256))
        return files


def main():
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    module_dir, package = sys.argv[1], sys.argv[2]
    tags = sys.argv[3] if len(sys.argv) == 4 else ""
    for path, sha256 in needed_module_files(module_dir, package, tags):
        directory, filename = path.rsplit("/", 1)
        print(f"- kind: remote\n"
              f"  url: goproxy:{path}\n"
              f"  directory: goproxy/{directory}\n"
              f"  filename: {filename}\n"
              f"  ref: {sha256}")


if __name__ == "__main__":
    main()

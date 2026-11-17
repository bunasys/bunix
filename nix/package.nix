# mkPackage: one package, built from its source by its build script.
#
#   name     the package; the store path is <hash>-<name>-<version>
#   source   an entry of sources.json: version, url, sha256
#   script   the build script: the commands that configure, build and
#            install into $out
#   tools    the packages whose bin/ make up PATH, first one first.  The
#            build can run nothing else, except /bin/sh.
#   env      more environment variables for the script.  A package becomes
#            its store path, a string stays itself.
#   mustNotDependOn
#            packages the result must not need to run, itself or
#            through anything else it needs: the build fails if it
#            does.  Nix takes a result to need every package whose
#            store path appears somewhere in it.
#
# What a build script can rely on (package.sh provides it):
#
#   - it is run by bash, with `set -euo pipefail`, in an empty directory;
#   - $src is the source tarball, $out is where to install;
#   - `unpack <tarball> [directory]` unpacks one, without its top directory;
#   - make runs in parallel (MAKEFLAGS);
#   - SOURCE_DATE_EPOCH is set, for programs that record when they were
#     built;
#   - afterwards, debugging information is stripped from everything in
#     $out, and libtool's .la files are deleted.
#
# `system` is the architecture built on and for, as Nix names it
# (aarch64-linux, x86_64-linux); the script sees it as $system.  `shell` is the bash that runs the scripts.
{ system, shell }:

{ name, source, script, tools, env ? {}, mustNotDependOn ? [] }:

let
  fetch = import ./fetch.nix;
  toolDirectories = map (tool: "${tool}/bin") tools;
in
derivation (env // {
  name = "${name}-${source.version}";
  inherit system;
  builder = shell;
  args = [ ./package.sh ];
  src = fetch source;
  inherit script;
  disallowedRequisites = mustNotDependOn;
  PATH = builtins.concatStringsSep ":" toolDirectories;
})

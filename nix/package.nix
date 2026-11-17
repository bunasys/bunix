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
#   mustNotReference
#            packages whose store paths must not appear anywhere in the
#            result: the build fails if one does.  A result that names
#            a package needs it to run, as far as Nix can tell, and
#            drags it along.
#
# What a build script can rely on (package.sh provides it):
#
#   - it is run by bash, with `set -euo pipefail`, in an empty directory;
#   - $src is the source tarball, $out is where to install;
#   - `unpack <tarball> [directory]` unpacks one, without its top directory;
#   - make runs in parallel (MAKEFLAGS);
#   - afterwards, debugging information is stripped from everything in
#     $out, and libtool's .la files are deleted.
#
# `system` is the architecture built on and for, as Nix names it
# (aarch64-linux, x86_64-linux); the script sees it as $system.  `shell` is the bash that runs the scripts.
{ system, shell }:

{ name, source, script, tools, env ? {}, mustNotReference ? [] }:

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
  disallowedReferences = mustNotReference;
  PATH = builtins.concatStringsSep ":" toolDirectories;
})

# mkPackage: one package, built from its source by its build script.
#
#   name     the package; the store path is <hash>-<name>-<version>
#   source   an entry of sources.json: version, url, sha256
#   script   the build script: the commands that configure, build and
#            install into $out
#   tools    the packages whose bin/ make up PATH, first one first.  The
#            build can run nothing else, except /bin/sh.
#   libraries
#            the packages whose headers and libraries the build uses:
#            only those listed, not the ones they use in turn.  gcc
#            finds their include/ and lib/ by itself (its variables
#            C_INCLUDE_PATH, CPLUS_INCLUDE_PATH and LIBRARY_PATH), and
#            LDFLAGS has the linker record each lib/ in what is built,
#            which is how the result finds them when it runs.
#
#            - Every library listed is then needed to run the result,
#              linked or not: list what is linked.
#            - A build that ignores LDFLAGS (a plain Makefile) has to be
#              given it by the script; one that hands LDFLAGS to ld
#              itself cannot take it, the flags are gcc's.
#            - Their headers come before glibc's and gcc's own.  glibc is
#              never listed: gcc knows where it is.
#            - PKG_CONFIG_PATH is set too, for when there is a pkg-config.
#   env      more environment variables for the script.  A package becomes
#            its store path, a string stays itself.
#   outputs  the store paths the result is split into, when it is more
#            than one: [ "out" "lib" ] gives the script $out and $lib.
#            "out" comes first; in Nix, `package` alone is it, and
#            `package.lib` the second.  What only needs the second does
#            not drag the first along.
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
#   - afterwards, debugging information is stripped from everything
#     installed, and libtool's .la files are deleted;
#   - the build fails if a program or library it installed asks for a
#     shared library that it would not find when run.
#
# `system` is the architecture built on and for, as Nix names it
# (aarch64-linux, x86_64-linux); the script sees it as $system.  `shell` is
# the bash that runs the scripts.
{ system, shell }:

{ name, source, script, tools, libraries ? [], env ? {}, outputs ? [ "out" ], mustNotDependOn ? [] }:

let
  fetch = import ./fetch.nix;
  toolDirectories = map (tool: "${tool}/bin") tools;

  includeDirectories = map (library: "${library}/include") libraries;
  libraryDirectories = map (library: "${library}/lib") libraries;
  pkgConfigDirectories =
    map (library: "${library}/lib/pkgconfig") libraries
    ++ map (library: "${library}/share/pkgconfig") libraries;
  recordLibraryDirectories = map (directory: "-Wl,-rpath,${directory}") libraryDirectories;

  # Not set at all without libraries: to gcc, an empty C_INCLUDE_PATH or
  # LIBRARY_PATH means the current directory.
  libraryVariables = if libraries == [] then {} else {
    C_INCLUDE_PATH = builtins.concatStringsSep ":" includeDirectories;
    CPLUS_INCLUDE_PATH = builtins.concatStringsSep ":" includeDirectories;
    LIBRARY_PATH = builtins.concatStringsSep ":" libraryDirectories;
    PKG_CONFIG_PATH = builtins.concatStringsSep ":" pkgConfigDirectories;
    LDFLAGS = builtins.concatStringsSep " " recordLibraryDirectories;
  };

  # A package's env that set one of these would replace it, and a replaced
  # LDFLAGS builds a program that cannot find its libraries when it runs.
  replaced = builtins.attrNames (builtins.intersectAttrs libraryVariables env);
in
if replaced != [] then
  throw "${name}: env sets ${builtins.concatStringsSep ", " replaced}, which `libraries` sets too; add to it in the build script instead (LDFLAGS=\"$LDFLAGS ...\")"
else
# Later wins: a package's env, then what mkPackage itself sets.
derivation (libraryVariables // env // {
  name = "${name}-${source.version}";
  inherit system;
  builder = shell;
  args = [ ./package.sh ];
  src = fetch source;
  inherit script outputs;
  disallowedRequisites = mustNotDependOn;
  PATH = builtins.concatStringsSep ":" toolDirectories;
})

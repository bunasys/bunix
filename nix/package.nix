# mkPackage: one package, built from its source by its build script.
#
#   name     the package; the store path is <hash>-<name>-<version>
#   source   an entry of sources.json: version, url, sha256
#   script   the build script: the commands that configure, build and
#            install into $out
#   tools    the packages whose bin/ make up PATH, first one first.  The
#            build can run nothing else, except /bin/sh.
#   libraries
#            the packages whose headers and libraries the build uses.
#            gcc finds their include/ and lib/ by itself (through its
#            variables C_INCLUDE_PATH and LIBRARY_PATH), pkg-config their
#            lib/pkgconfig, and LDFLAGS has the linker record each lib/
#            in what is built, which is how the result finds them when
#            it runs.  A script whose build system ignores LDFLAGS has
#            to pass it on itself.
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
#     installed, and libtool's .la files are deleted.
#
# `system` is the architecture built on and for, as Nix names it
# (aarch64-linux, x86_64-linux); the script sees it as $system.  `shell` is
# the bash that runs the scripts.  `environment` is variables for every
# package made with this mkPackage; a package's own env wins.
{ system, shell, environment ? {} }:

{ name, source, script, tools, libraries ? [], env ? {}, outputs ? [ "out" ], mustNotDependOn ? [] }:

let
  fetch = import ./fetch.nix;
  toolDirectories = map (tool: "${tool}/bin") tools;

  inEachLibrary = directory: separator:
    builtins.concatStringsSep separator (map (library: "${library}/${directory}") libraries);

  # Not set at all without libraries: to gcc, an empty C_INCLUDE_PATH or
  # LIBRARY_PATH means the current directory.
  librarySearchPaths = if libraries == [] then {} else {
    C_INCLUDE_PATH = inEachLibrary "include" ":";
    CPLUS_INCLUDE_PATH = inEachLibrary "include" ":";
    LIBRARY_PATH = inEachLibrary "lib" ":";
    PKG_CONFIG_PATH = inEachLibrary "lib/pkgconfig" ":";
    LDFLAGS = builtins.concatStringsSep " " (map (library: "-Wl,-rpath,${library}/lib") libraries);
  };
in
derivation (environment // librarySearchPaths // env // {
  name = "${name}-${source.version}";
  inherit system;
  builder = shell;
  args = [ ./package.sh ];
  src = fetch source;
  inherit script outputs;
  disallowedRequisites = mustNotDependOn;
  PATH = builtins.concatStringsSep ":" toolDirectories;
})

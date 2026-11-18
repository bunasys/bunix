# mkSystemPackage: one package of the bunix system (docs/nix-usr-system.md).
#
# It is configured for /usr and installed into its result, which is a
# tree: $out/usr/..., and $out/etc/... if it has configuration.  Nothing in
# it names the store.
#
#   name, source, script
#            as for a bootstrap package (package.nix).  The script
#            installs with DESTDIR=$out.
#   depends  the system packages it needs to run.  An image that has this
#            package has them too.
#   buildDepends
#            the system packages only its build needs.
#   tools    bootstrap packages whose bin/ come after /usr/bin on PATH: the
#            compiler and tools of stages 1 and 2, for the packages built
#            before the system has its own.
#   env      more environment variables for the script.
#
# The build runs with /usr made of depends and buildDepends, and of what
# those need in turn (stage.sh).  What a script can rely on is in
# system-package.sh.
#
# `stagingTools` are the bootstrap packages that do the staging: unshare,
# mount, chroot.
{ system, shell, stagingTools }:

{ name, source, script, depends ? [], buildDepends ? [], tools ? [], env ? {} }:

let
  fetch = import ./fetch.nix;
  binDirectories = packages:
    builtins.concatStringsSep ":" (map (package: "${package}/bin") packages);
  staged = depends ++ buildDepends;
in
derivation (env // {
  name = "${name}-${source.version}";
  inherit system;
  builder = shell;
  args = [ ./stage.sh ];
  src = fetch source;
  inherit script depends;

  PATH = binDirectories stagingTools;
  toolsPath = binDirectories tools;
  # what stage.sh runs once /usr is in place
  inside = ./system-package.sh;

  # For each staged package, Nix writes a file closure-<name> in the build
  # directory: every store path it needs to run, itself included.  A
  # system package names the ones it needs in its `depends` file.
  exportReferencesGraph =
    builtins.concatLists (map (package: [ "closure-${package.name}" package ]) staged);
})

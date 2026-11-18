# mkSystemPackage: one package of the bunix system (docs/nix-usr-system.md).
#
# It is configured for /usr and installed into its result, which is a
# tree: $out/usr/..., and $out/etc/... if it has configuration.  Nothing in
# it names the store, except the file $out/depends.
#
#   name, source, script
#            as for a bootstrap package (package.nix).  The script
#            installs with DESTDIR=$out.
#   version  in place of source, for a package made from another's
#            result and not from a source of its own (toolchain.nix has
#            two)
#   depends  the system packages it needs to run.  An image that has this
#            package has them too.
#   buildDepends
#            the system packages only its build needs.
#   env      more environment variables for the script.
#
# The build runs with /usr made of depends and buildDepends, and of what
# those need in turn (stage.nix).  What a script can rely on, and what is
# checked of its result, is in system-package.sh.
#
# `bootstrapTools` are for a group of packages built before the system has
# a compiler and tools of its own: stage 1's and stage 2's, after /usr/bin
# on PATH.  `stagingTools`: see stage.nix.
{ system, shell, stagingTools, bootstrapTools ? [] }:

{ name, script, source ? null, version ? source.version, depends ? [], buildDepends ? [], env ? {} }:

let
  fetch = import ./fetch.nix;
  stagedBuild = import ./stage.nix { inherit system shell stagingTools; };
  sourceVariable = if source == null then {} else { src = fetch source; };
in
stagedBuild {
  name = "${name}-${version}";
  run = ./system-package.sh;
  inherit depends buildDepends bootstrapTools;
  env = env // sourceVariable // { inherit script; };
}

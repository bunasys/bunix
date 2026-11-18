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
#   builtElsewhere
#            true for a program published as a program, not as source.
#            It is shipped as it was published, and not held to what
#            only a build here can ensure (system-package.sh).
#
# The build runs with /usr made of depends and buildDepends, and of what
# those need in turn (stage.nix).  What a script can rely on, and what is
# checked of its result, is in system-package.sh.
#
# What a group of packages has in common is said once, where the group is
# defined (toolchain.nix, tools.nix, base.nix, boot.nix):
#
#   bootstrapTools
#            for a group built before the system has a compiler and tools
#            of its own: stage 1's and stage 2's, after /usr/bin on PATH
#   buildEnvironment
#            system packages that are buildDepends of every package of the
#            group: the compiler and the tools
#   defaultEnv
#            variables every package of the group starts with, such as
#            the compiler's flags; a package's env wins
{ system, bootstrapTools ? [], buildEnvironment ? [], defaultEnv ? {} }:

{ name, script, source ? null, version ? null, depends ? [], buildDepends ? [], env ? {}, builtElsewhere ? false }:

let
  fetch = import ./fetch.nix;
  stagedBuild = import ./stage.nix { inherit system; };
  packageVersion =
    if source != null then source.version
    else if version != null then version
    else throw "${name} has neither a source nor a version";
  sourceVariable = if source == null then {} else { src = fetch source; };
in
stagedBuild {
  name = "${name}-${packageVersion}";
  run = ./system-package.sh;
  inherit depends bootstrapTools;
  buildDepends = buildEnvironment ++ buildDepends;
  # later wins
  env = defaultEnv // env // sourceVariable // {
    inherit script;
    built_elsewhere = if builtElsewhere then "yes" else "";
  };
}

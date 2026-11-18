# stagedBuild: a build that runs with /usr made of system packages
# (stage.sh does the staging; docs/nix-usr-system.md says why).
#
#   name     of the result
#   run      the script to run inside, once /usr is in place
#   depends  the system packages the result needs to run.  They are staged,
#            with everything they need in turn, and are the only store
#            paths the result may name: Nix fails the build otherwise.
#   buildDepends
#            system packages staged for the build only
#   bootstrapTools
#            bootstrap packages whose bin/ come after /usr/bin on PATH
#   contents for a build that makes an image: the system packages to put
#            in it.  They are not staged; the script gets them, and all
#            they need to run, as $contents_packages.
#   env      more environment variables for the script
#
# mkSystemPackage is this with system-package.sh as the script; the tests
# of the system's packages use it directly.
#
# `stagingTools` are the bootstrap packages that do the staging: unshare,
# mount, chroot.
{ system, shell, stagingTools }:

{ name, run, depends ? [], buildDepends ? [], bootstrapTools ? [], contents ? [], env ? {} }:

let
  architecture = import ./architecture.nix system;
  binDirectories = packages:
    builtins.concatStringsSep ":" (map (package: "${package}/bin") packages);

  # For each staged package, Nix writes a file in the build directory with
  # every store path it needs to run, itself included (a system package
  # names what it needs in its `depends` file).  The attribute is a list of
  # file name, package, file name, package...; a file is named after the
  # kind of dependency and the package's store path.
  closureFiles = kind: packages:
    builtins.concatLists (map
      (package: [ "closure-${kind}-${baseNameOf package.outPath}" package ])
      packages);
in
derivation (env // {
  inherit name system depends;
  inherit (architecture) triplet loader;
  builder = shell;
  args = [ ./stage.sh ];
  PATH = binDirectories stagingTools;
  bootstrap_path = binDirectories bootstrapTools;
  run_inside = run;
  allowedReferences = depends;
  exportReferencesGraph =
    closureFiles "run" depends ++ closureFiles "build" buildDepends ++ closureFiles "contents" contents;
})

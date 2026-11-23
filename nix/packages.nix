# Packages a person installs on their own machine: `bunix install less`
# (src/bunix).  Not in the system, nor in an extension: each is built on
# the machine, by the llvm extension's compiler, from the recipe here,
# and installed in /usr/local.
#
#   nix-build /bunix/nix/packages.nix -A built.less    the package, built here
#   nix-build /bunix/nix/packages.nix -A recipes       what the machine is given
#
# A recipe is what base.nix has for a package, as data, so that it can be
# both built here and handed to a machine:
#
#   description   a line for a person choosing
#   source        of sources.json
#   script        the build's script; it must take where it installs from
#                 $configure_for_usr (../autotools.sh does; meson.sh and
#                 cmake.sh name /usr themselves, and are not for here yet)
#   env           variables for the script: strings only, and so no
#                 patches (base.nix's env.patches): a recipe that needs
#                 one cannot be handed to a machine yet
#   depends, buildDepends
#                 system packages, for the build here.  On a machine
#                 there is the system and the llvm extension: what a
#                 recipe depends on has to be in those.
#   needs         other recipes, by name, that a machine installs first
#
# Each is built here too, as a system package, for /usr and by gcc: a
# recipe that does not build is not handed to anyone.  That is not the
# build a machine does (clang, /usr/local), which tools/update-test.sh
# tries for one.
{ system ? builtins.currentSystem }:

let
  toolchain = import ./toolchain.nix { inherit system; };
  tools = import ./tools.nix { inherit system; };
  base = import ./base.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ./sources.json);
  inherit (toolchain) glibc;

  mkSystemPackage = import ./system-package.nix {
    inherit system;
    inherit (tools) buildEnvironment;
    defaultEnv = tools.compilerFlags;
  };

  recipes = {
    # less: the pager.  POSIX regular expressions from glibc: there is no
    # pcre2 to count on.
    less = {
      description = "less, the pager";
      source = sources.less;
      script = ./autotools.sh;
      env = { configure_arguments = "--with-regex=posix"; };
      depends = [ glibc tools.ncurses ];
    };

    htop = {
      description = "htop, the interactive process viewer";
      source = sources.htop;
      script = ./packages/htop.sh;
      depends = [ glibc tools.ncurses ];
      buildDepends = [ base.pkgconf ];
    };
  };

  built = builtins.mapAttrs (name: recipe: mkSystemPackage {
    inherit name;
    inherit (recipe) source script;
    depends = recipe.depends or [];
    buildDepends = recipe.buildDepends or [];
    env = recipe.env or {};
  }) recipes;

  # ---- What a machine is given -----------------------------------------------

  lines = list: builtins.concatStringsSep "\n" list + "\n";
  # A value as a word of a shell script.
  quoted = value: "'" + builtins.replaceStrings [ "'" ] [ "'\\''" ] value + "'";

  # A recipe's three files (packages/recipes.sh says what each is for):
  # the first two written here, the third the script as it is.  As one
  # word for the build of `recipes`: name:about:environment:script.
  filesOf = name: recipe:
    let
      about = builtins.toFile "${name}-about" (lines [
        "version=${recipe.source.version}"
        "description=${recipe.description}"
        "url=${recipe.source.url}"
        "sha256=${recipe.source.sha256}"
        "needs=${builtins.concatStringsSep " " (recipe.needs or [])}"
      ]);
      environment = builtins.toFile "${name}-environment" (lines (builtins.attrValues (builtins.mapAttrs
        (variable: value: "export ${variable}=${quoted value}") (recipe.env or {}))));
    in
    "${name}:${about}:${environment}:${recipe.script}";
in
{
  inherit built;

  # The recipes, and what builds one on a machine, as a system package:
  # for the llvm extension (images/llvm.nix).
  recipes = mkSystemPackage {
    name = "bunix-recipes";
    version = import ./release.nix;
    script = ./packages/recipes.sh;
    depends = [ tools.bash ];
    env = {
      recipes = builtins.attrValues (builtins.mapAttrs filesOf recipes);
      build_package = ./packages/build-package;
      # Not read by the script: named so that a recipe that does not
      # build here stops this package, and is handed to no machine.
      built_here = builtins.attrValues built;
    };
  };
}

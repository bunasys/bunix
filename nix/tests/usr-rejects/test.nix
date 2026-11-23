# What a system package may not be: each of these builds must fail, with
# the message tests/run.sh expects of it (the file `expected` here).
#
#   nix-build /bunix/nix/tests/usr-rejects/test.nix -A storePathInFile     (fails)
{ system ? builtins.currentSystem }:

let
  stage2 = import ../../bootstrap/stage2.nix { inherit system; };
  toolchain = import ../../toolchain.nix { inherit system; };
  sources = builtins.fromJSON (builtins.readFile ../../sources.json);

  mkSystemPackage = import ../../system-package.nix {
    inherit system;
    bootstrapTools = stage2.all;
  };
  stagedBuild = import ../../stage.nix { inherit system; };

  # A package made by running one function of cases.sh.  Its source is not
  # used: mkSystemPackage wants one.
  rejected = case: mkSystemPackage {
    name = "rejected-${case}";
    source = sources.zlib;
    script = ./cases.sh;
    depends = [ toolchain.glibc ];
    buildDepends = [ toolchain.gcc ];
    env = { inherit case; };
  };

  # two packages with the same file, for a third to be staged with
  sameFile = name: stagedBuild {
    name = "same-file-${name}";
    run = ./same-file.sh;
    bootstrapTools = stage2.all;
    env = { inherit name; };
  };
in
{
  storePathInFile = rejected "store_path_in_file";
  linkIntoStore = rejected "link_into_store";
  undeclaredLibrary = rejected "undeclared_library";
  libraryOutsideTriplet = rejected "library_outside_triplet";
  scriptWithoutInterpreter = rejected "script_without_interpreter";

  sameFileTwice = stagedBuild {
    name = "rejected-same-file-twice";
    run = ./same-file.sh;
    buildDepends = [ (sameFile "a") (sameFile "b") ];
    bootstrapTools = stage2.all;
    env = { name = "c"; };
  };
}

# fetch: a source, downloaded and pinned.  The build fails unless the file
# has this sha256, which is why it may use the network when no other build
# can.  Nix does the download itself; it needs no tools from the store.
{ url, sha256, ... }:

derivation {
  name = baseNameOf url;
  system = "builtin";
  builder = "builtin:fetchurl";
  inherit url;
  outputHashAlgo = "sha256";
  outputHashMode = "flat";
  outputHash = sha256;
}

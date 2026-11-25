# systemd-boot signed for Secure Boot, which shim starts (signed-loader.sh
# says how, and of whose key): for x86's /usr (images/system.nix), from
# where bunix-install puts it on an ESP, and for the live stick
# (images/live.nix), as one build.
#
#   signing, secureBootLoader
#            as images/system.nix takes them: a test system's is signed
#            in this build, with the development key; a release's is
#            handed to it, signed with bunix's
{ system ? builtins.currentSystem, signing ? "development", secureBootLoader ? null }:

let
  tools = import ../tools.nix { inherit system; };
  base = import ../base.nix { inherit system; };
  stagedBuild = import ../stage.nix { inherit system; };
in
stagedBuild {
  name = "bunix-signed-systemd-boot";
  run = ./signed-loader.sh;
  # osslsigncode: what signs, and checks a release's; openssl: what makes
  # the certificate a file MokManager takes
  buildDepends = [ base.systemd base.osslsigncode base.openssl tools.bash tools.coreutils tools.sed ];
  env = {
    sign_kernel_image = ../../tools/sign-kernel-image.sh;
    # (it takes these four from the environment: sign_kernel_image,
    # development_key, development_certificate, release_certificate)
    check_release_signed = ./check-release-signed.sh;
    development_key = ../development-key/development.key;
    development_certificate = ../development-key/development.crt;
    release_signed = if secureBootLoader == null then "" else secureBootLoader;
    release_certificate = ../../keys/secureboot.crt;
  };
}

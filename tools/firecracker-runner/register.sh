#!/bin/bash
# Registers a runner for one repository with GitHub, once, and packs the
# registration into config-<n>.ext4, the drive instance <n>'s VMs read it
# from (install.sh).  Run on x86_64 Linux, in the directory where
# build-guest.sh left the runner tarball.  The token is a runner
# registration token for the repository, valid for an hour:
#
#   gh api -X POST repos/<owner>/<repo>/actions/runners/registration-token --jq .token
#
#   tools/firecracker-runner/register.sh <n> <owner>/<repo> <token> <name>
#
# The runner takes only jobs that ask for its label (runs-on:
# bunix-firecracker), never the "self-hosted" ones meant for other machines.
# It does not update itself (a VM's update would be lost with the VM):
# GitHub refuses runners more than 30 days behind the latest release, so
# rebuild the image with a newer runner_version before then.
set -euo pipefail
index=$1
repository=$2
token=$3
name=$4

rm -rf registration config
mkdir registration config
tar -xzf actions-runner-linux-x64-*.tar.gz -C registration
(
  cd registration
  DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 ./config.sh --unattended \
    --url "https://github.com/$repository" --token "$token" --name "$name" \
    --labels bunix-firecracker --no-default-labels --work _work \
    --replace --disableupdate
)
cp registration/.runner registration/.credentials registration/.credentials_rsaparams config/
drive=config-$index.ext4
rm -f "$drive"
truncate -s 4M "$drive"
mkfs.ext4 -q -d config -F "$drive"
rm -rf registration config
chmod 600 "$drive"
ls -l "$drive"

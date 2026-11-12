#!/bin/sh
# Runs as the job's last step, before the runner reports the result: the
# stop waits a few seconds so the report gets out.  (The runner takes only
# hooks named *.sh, *.ps1 or *.js.)
sudo systemd-run --quiet --on-active=10 --unit=runner-recycle \
  /usr/bin/systemctl stop actions-runner.service

#!/bin/sh
# Merges GN argument files into one args.gn, on standard output:
#
#   merge-gn-args.sh ungoogled/flags.gn hudhud-args.gn > out/Release/args.gn
#
# GN refuses an argument set twice, so an argument set again in a later file
# replaces the earlier setting: Hudhud's own choices (the last file) win
# over ungoogled-chromium's.  Each argument keeps the place it first had;
# comments are dropped.
cat "$@" | awk '
  /^[a-z_0-9]+ *=/ {
    name = $0
    sub(/ *=.*/, "", name)
    if (!(name in setting)) order[++count] = name
    setting[name] = $0
  }
  END { for (i = 1; i <= count; i++) print setting[order[i]] }
'

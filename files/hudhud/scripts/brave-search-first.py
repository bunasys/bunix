#!/usr/bin/env python3
"""Puts Brave Search in every country's list of search engines, first.

The brave-search-default patch (make-patches.py) makes the engine with
Brave's id the default, so Brave must be in every list (in
third_party/search_engines_data/resources/definitions/regional_settings.json).
Why, and why on the data rather than as a patch: docs/browser.md, "Defaults".
A change of engine is made here (BRAVE) and in the patches.

    brave-search-first.py <chromium source directory>
"""

import json
import re
import sys

BRAVE = "&brave"

source = sys.argv[1]
path = f"{source}/third_party/search_engines_data/resources/definitions/regional_settings.json"
text = open(path, encoding="utf-8").read()

# The file starts with a licence header in // comments, which JSON does not
# allow: kept as it is, around the parsed body.
header = re.match(r"(?:\s*//[^\n]*\n)*", text).group(0)
settings = json.loads(text[len(header):])

countries = settings["elements"]
for country in countries.values():
    engines = country["search_engines"]
    if BRAVE in engines:
        engines.remove(BRAVE)
    engines.insert(0, BRAVE)

with open(path, "w", encoding="utf-8") as out:
    out.write(header)
    json.dump(settings, out, indent=2, ensure_ascii=False)
    out.write("\n")

print(f"Brave Search first in {len(countries)} countries")

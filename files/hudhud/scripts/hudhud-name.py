#!/usr/bin/env python3
"""Names the browser Hudhud instead of Chromium in its user interface.

The browser's strings are GRIT messages (.grd and .grdp files), translated in
.xtb files.  A translation is found by its message's id, which GRIT computes
from the English text: renaming the browser in the English alone would leave
every other language without its translations, falling back to English.  So
the browser is renamed in the English, and each of its translations is given
the renamed message's id and renamed too: هدهد in Arabic, Hudhud in the other
languages.  Done on the data, not as a patch, so that it keeps working when
Chromium adds or edits strings.

    hudhud-name.py <chromium source directory>
"""

import hashlib
import os
import re
import sys
import xml.etree.ElementTree as ET

# The .grd files whose messages, or the messages of their <part> .grdp files,
# name the browser.  ChromeOS, Android and iOS strings are left alone.
GRDS = [
    "chrome/app/chromium_strings.grd",
    "chrome/app/generated_resources.grd",
    "components/components_chromium_strings.grd",
    "components/components_strings.grd",
    "components/privacy_sandbox_strings.grd",
    "extensions/strings/extensions_strings.grd",
]

# "Chromium" as the browser's name, but not the project it is built from:
# "The Chromium Authors", ChromiumOS, the "Chromium open source project", and
# the link to the Chromium project on the About page, the word between two
# placeholders (<ph name="END_LINK_CHROMIUM"> in a .grd, <ph ... /> in a .xtb).
BROWSER_NAME = re.compile(
    r'Chromium(?! Authors|OS| OS| open source|<ph name="END_LINK_CHROMIUM")'
)
NEW_NAME = "Hudhud"
ARABIC_NAME = "هدهد"

# Chromium does not translate its own name, so these are marked
# translateable="false"; Hudhud's is translated into Arabic.
PRODUCT_NAMES = ["IDS_PRODUCT_NAME", "IDS_SHORT_PRODUCT_NAME", "IDS_APP_MENU_PRODUCT_NAME"]
PRODUCT_NAMES_GRD = "chrome/app/chromium_strings.grd"

MESSAGE = re.compile(r"(<message\b[^>]*>)(.*?)(</message>)", re.DOTALL)
TRANSLATION = re.compile(r'<translation id="(\d+)">(.*?)</translation>', re.DOTALL)


def read(path):
    # A Chromium update that moves a file must stop the build, not quietly
    # leave the browser named Chromium.
    if not os.path.exists(path):
        sys.exit(f"hudhud-name.py: {path} is missing")
    return open(path, encoding="utf-8").read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as out:
        out.write(text)


def fingerprint(text):
    """GRIT's fingerprint: the first 64 bits of the MD5, as a signed number."""
    number = int(hashlib.md5(text.encode("utf-8")).hexdigest()[:16], 16)
    if number >= 1 << 63:
        number -= 1 << 64
    return number


def message_id(message_xml):
    """The id GRIT gives a message (GenerateMessageId in grit/extern/tclib.py)."""
    message = ET.fromstring(message_xml)

    # GRIT fingerprints the text with each <ph> replaced by its name in upper
    # case, trimmed, and without the ''' that keep spaces at its ends.
    parts = [message.text or ""]
    for placeholder in message:
        parts.append(placeholder.get("name").upper())
        parts.append(placeholder.tail or "")
    text = "".join(parts).strip()
    text = text.removeprefix("'''").removesuffix("'''").strip()

    number = fingerprint(text)
    meaning = message.get("meaning", "")
    if meaning:
        number = fingerprint(meaning) + (number << 1) + (1 if number < 0 else 0)
    return str(number & 0x7FFFFFFFFFFFFFFF)


def grit_files(grd):
    """The .grd and the .grdp files it includes, however deeply."""
    files = [grd]
    for part in ET.fromstring(read(grd)).iter("part"):
        files += grit_files(os.path.join(os.path.dirname(grd), part.get("file")))
    return files


def rename_in_messages(path):
    """Renames the browser in the English messages; returns {old id: new id}."""
    new_ids = {}

    def rename(match):
        start, body, end = match.groups()
        if not BROWSER_NAME.search(body):
            return match.group(0)

        is_product_name = any(f'name="{name}"' in start for name in PRODUCT_NAMES)
        if is_product_name:
            start = start.replace(' translateable="false"', "")
        renamed = start + BROWSER_NAME.sub(NEW_NAME, body) + end

        # Untranslatable messages have no translations to carry over.
        is_translated = 'translateable="false"' not in start
        if is_translated:
            new_ids[message_id(match.group(0))] = message_id(renamed)
        return renamed

    write(path, MESSAGE.sub(rename, read(path)))
    return new_ids


def rename_in_translations(path, new_name, new_ids):
    """Gives renamed messages' translations their new ids; returns how many."""
    renamed = 0

    def rename(match):
        nonlocal renamed
        old_id, translation = match.groups()
        if old_id not in new_ids:
            return match.group(0)
        renamed += 1
        translation = BROWSER_NAME.sub(new_name, translation)
        return f'<translation id="{new_ids[old_id]}">{translation}</translation>'

    write(path, TRANSLATION.sub(rename, read(path)))
    return renamed


def add_arabic_product_name(source):
    """Chromium does not translate its own name; Hudhud's is هدهد in Arabic.
    The product names, now translatable, all have the text "Hudhud" and so
    one id: only Arabic gets a translation, the other languages fall back to
    English."""
    grd_path = os.path.join(source, PRODUCT_NAMES_GRD)
    product_names = read(grd_path)
    for name in PRODUCT_NAMES:
        translatable_hudhud = rf'<message name="{name}"(?![^>]*translateable="false")[^>]*>\s*{NEW_NAME}\s*</message>'
        if not re.search(translatable_hudhud, product_names):
            sys.exit(f"hudhud-name.py: {name} is not a translatable {NEW_NAME} in {PRODUCT_NAMES_GRD}")

    arabic_xtb_path = None
    for xtb in ET.fromstring(product_names).iter("file"):
        if xtb.get("lang") == "ar":
            arabic_xtb_path = os.path.join(os.path.dirname(grd_path), xtb.get("path"))
    if arabic_xtb_path is None:
        sys.exit(f"hudhud-name.py: {PRODUCT_NAMES_GRD} has no Arabic translations")

    product_name_id = message_id(f"<message>{NEW_NAME}</message>")
    arabic = read(arabic_xtb_path)
    # Were a translatable message just "Chromium", its translation would
    # already have this id; a second one would be a duplicate.
    if f'<translation id="{product_name_id}">' in arabic:
        return
    translation = f'<translation id="{product_name_id}">{ARABIC_NAME}</translation>\n'
    write(arabic_xtb_path, arabic.replace("</translationbundle>", translation + "</translationbundle>"))


source = sys.argv[1]
grds = [os.path.join(source, grd) for grd in GRDS]

# Some .grdp files are part of two .grd files: each is renamed once, and the
# ids of all of them are collected together, which is safe because an id
# depends only on a message's text.
grit_paths = []
for grd in grds:
    for path in grit_files(grd):
        if path not in grit_paths:
            grit_paths.append(path)
new_ids = {}
for path in grit_paths:
    new_ids.update(rename_in_messages(path))

# Run twice, or on a Chromium whose strings moved, nothing is renamed: that
# must stop the build rather than ship a browser still named Chromium.
if not new_ids:
    sys.exit("hudhud-name.py: no message names Chromium (already renamed, or Chromium's strings moved)")

translations = 0
for grd in grds:
    for xtb in ET.fromstring(read(grd)).iter("file"):
        xtb_path = os.path.join(os.path.dirname(grd), xtb.get("path"))
        new_name = ARABIC_NAME if xtb.get("lang") == "ar" else NEW_NAME
        translations += rename_in_translations(xtb_path, new_name, new_ids)

add_arabic_product_name(source)
print(f"Hudhud named in {len(new_ids)} messages and {translations} of their translations")

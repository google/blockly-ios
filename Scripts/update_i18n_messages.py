#!/usr/bin/python

# Downloads all localized message files from the Blockly web repo and
# updates the corresponding JSON message files in Blockly iOS.
#
# NOTE: `git` needs to be installed for this script to run.
#
# Usage:
# python update_i18n_messages.py
#
# Copyright 2017 Google Inc.
# https://developers.google.com/blockly/
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import json
import shutil
import sys
from common import InputError
from common import git_clone
from common import read_json_file
from os import path
from os import walk

def update_i18n_messages(blockly_ios_root, blockly_web_root):
  """Updates JSON message files for all supported languages in Blockly iOS,
  using a local Blockly web repo as the source.

  Args:
    blockly_ios_root: Root directory of the Blockly iOS repo.
    blockly_web_root: Root directory of the Blockly web repo.
  """

  ios_messages_dir = path.realpath(
    path.join(blockly_ios_root, "Resources/Localized/Messages"))
  web_json_dir = path.realpath(path.join(blockly_web_root, "msg/json"))
  ios_constants_file_name = "bky_constants.json"
  ios_messages_file_name = "bky_messages.json"
  ios_synonyms_file_name = "bky_synonyms.json"

  # Copy constants and synonyms directly from web repo to iOS dir
  shutil.copyfile(
    path.join(web_json_dir, "constants.json"),
    path.join(ios_messages_dir, ios_constants_file_name))
  shutil.copyfile(
    path.join(web_json_dir, "synonyms.json"),
    path.join(ios_messages_dir, ios_synonyms_file_name))

  # The English JSON file contains all possible messages in Blockly.
  # Use it as a basis for re-building all other localized JSON files
  # (whose original files may not contain translations for all keys).
  all_messages = read_json_file(path.join(web_json_dir, "en.json"))

  # Get list of JSON files from web repo
  json_files = []
  for (dirpath, dirnames, filenames) in walk(web_json_dir):
    json_files.extend(filenames)
    break

  # Create corresponding JSON files in iOS for those web files
  for json_file in json_files:
    if (not json_file.endswith(".json") or
      json_file in ["qqq.json", "constants.json", "synonyms.json"]):
      # Ignore these files.
      continue

    # Check if localization has been set up for this language in Blockly iOS
    language_code = mapped_language_code(json_file.replace(".json", ""))
    ios_language_dir = path.join(ios_messages_dir, language_code + ".lproj")

    if language_code in ["ab", "ba", "bcc", "diq", "hrx", "ia", "lki", "oc",
    "pms", "sc", "sd", "shn", "tcy", "tl", "tlh"]:
      print """Skipping "{0}", which is an unsupported language code \
in iOS.""".format(language_code)
      continue
    elif not path.exists(ios_language_dir):
      # Skip this language since it needs to be setup in the iOS library first.
      print """[WARNING] Skipping "{0}" since its localization hasn't been set \
up in Blockly iOS.
To fix: In Xcode, go to Project Settings > Info > Localizations, and add \
localization for "{1}".""".format(json_file, language_code)
      continue

    # Create a JSON dictionary that starts with all messages as a base.
    all_localized_messages = all_messages.copy()

    # Now overwrite those messages with any found for this language.
    web_json_path = path.join(web_json_dir, json_file)
    all_localized_messages.update(read_json_file(web_json_path))

    # Output JSON dictionary to iOS file
    ios_json_path = path.join(ios_language_dir, ios_messages_file_name)
    with open(ios_json_path, "w") as outfile:
      json.dump(all_localized_messages, outfile, sort_keys=True,
        indent=2, separators=(',', ': '))

  print "Finished updating localization files."

def mapped_language_code(language_code):
  # The following codes don't exist in iOS, but can be mapped to different
  # locales.
  if language_code == "be-tarask":
    return "be" # Belarusian

  # Just return back the original language code
  return language_code

if __name__ == '__main__':
  script_description = """
Downloads all localized message files from the Blockly web repo and
updates the corresponding JSON message files in Blockly iOS.
(NOTE: `git` needs to be installed for this script to run.)"""

  # Parse command-line args
  parser = argparse.ArgumentParser(description=script_description)
  parser.add_argument("--branch",
    help="The git branch to use from the Blockly web repo. Defaults to 'master'.",
    default="master")
  args = parser.parse_args()

  script_dir = path.dirname(path.realpath(sys.argv[0]))
  blockly_ios_root = path.realpath(path.join(script_dir, ".."))

  # Create temp dir
  temp_dir = path.realpath(path.join(script_dir, "temp"))
  if (path.exists(temp_dir)):
    shutil.rmtree(temp_dir)

  # Clone master branch of blockly
  git_clone(temp_dir, "https://github.com/google/blockly.git", "--branch " + args.branch + " --depth 1")
  blockly_web_root = path.join(temp_dir, "blockly")

  # Update i18n messages with the cloned repo
  update_i18n_messages(blockly_ios_root, blockly_web_root)

  # Clean up temp dir
  shutil.rmtree(temp_dir)

#!/usr/bin/python2.7
# Updates all required *_compressed.js files from web Blockly.
#
# Usage:
# ./pull_web_blockly
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

import distutils.dir_util
import os
import shutil
import urllib2
import sys

def pullFile(folderName, fileName):
  attempts = 0
  while attempts < 3:
    try:
      remote = "https://raw.githubusercontent.com/google/blockly/master/"
      remote = remote + folderName + fileName
      localFolder = "temp/" + folderName
      if (not os.path.exists(localFolder)):
        os.makedirs(localFolder)
      response = urllib2.urlopen(remote)
      text = response.read()
      output = open(localFolder + fileName, 'w')
      output.write(text)
      output.close()
      return
    except urllib2.URLError as e:
      attempts += 1
      print type(e)

script_dir = os.path.dirname(os.path.realpath(sys.argv[0]))
os.chdir(script_dir + "/../Samples")
if (not os.path.exists("temp")):
  os.mkdir("temp")
pullFile("", "blockly_compressed.js")
pullFile("", "javascript_compressed.js")
pullFile("msg/js/", "en.js")

dest = "BlocklyCodeLab/BlocklyCodeLab/Resources/Non-Localized/blockly_web/"
distutils.dir_util.copy_tree("temp/", dest)
dest = "BlocklyCodeLab-Starter/BlocklyCodeLabStarter/Resources/Non-Localized/blockly_web"
distutils.dir_util.copy_tree("temp/", dest)
dest = "BlocklySample/BlocklySample/Resources/Non-Localized/Turtle/blockly_web"
distutils.dir_util.copy_tree("temp/", dest)

pullFile("", "python_compressed.js")
dest = "../Tests/Resources/blockly_web"
distutils.dir_util.copy_tree("temp/", dest)

shutil.rmtree("temp")

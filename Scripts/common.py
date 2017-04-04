#!/usr/bin/python

# Code shared by translation scripts.
#
# Copyright 2013 Google Inc.
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

import codecs
import json
import os
from datetime import datetime

class InputError(Exception):
    """Exception raised for errors in the input.

    Attributes:
        location -- where error occurred
        msg -- explanation of the error

    """

    def __init__(self, location, msg):
        Exception.__init__(self, '{0}: {1}'.format(location, msg))
        self.location = location
        self.msg = msg


def read_json_file(filename):
  """Read a JSON file as UTF-8 into a dictionary, discarding @metadata.

  Args:
    filename: The filename, which must end ".json".

  Returns:
    The dictionary.

  Raises:
    InputError: The filename did not end with ".json" or an error occurred
        while opening or reading the file.
  """
  if not filename.endswith('.json'):
    raise InputError(filename, 'filenames must end with ".json"')
  try:
    # Read in file.
    with codecs.open(filename, 'r', 'utf-8') as infile:
      defs = json.load(infile)
    if '@metadata' in defs:
      del defs['@metadata']
    return defs
  except ValueError, e:
    print('Error reading ' + filename)
    raise InputError(filename, str(e))

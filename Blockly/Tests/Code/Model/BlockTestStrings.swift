/*
* Copyright 2016 Google Inc. All Rights Reserved.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import Foundation

class BlockTestStrings {
  static let EMPTY_BLOCK_WITH_POSITION = "<block type=\"empty_block\" id=\"364\" x=\"37\" y=\"13\" />"
  static let EMPTY_BLOCK_NO_POSITION = "<block type=\"empty_block\" id=\"364\" />"

  static let BLOCK_START = "<block type=\"frankenblock\" id=\"364\" x=\"37\" y=\"13\">"
  static let BLOCK_START_NO_POSITION = "<block type=\"frankenblock\" id=\"364\">"
  static let BLOCK_END = "</block>"

  static let SIMPLE_BLOCK =
  "<block type=\"frankenblock\" id=\"364\" x=\"37\" y=\"13\">" +
    "<field name=\"text_input\">item</field>" +
  "</block>"

  static let NO_BLOCK_TYPE =
  "<block id=\"364\" x=\"37\" y=\"13\">" +
    "<field name=\"text_input\">item</field>" +
  "</block>"

  static let NO_BLOCK_ID =
  "<block type=\"frankenblock\" x=\"37\" y=\"13\">" +
    "<field name=\"text_input\">item</field>" +
  "</block>"

  static let NO_BLOCK_POSITION =
  "<block type=\"frankenblock\" id=\"364\">" +
    "<field name=\"text_input\">item</field>" +
  "</block>"

  static let FIELD_HAS_NAME = "<field name=\"text_input\">item</field>"
  static let FIELD_MISSING_NAME = "<field>item</field>"
  static let FIELD_UNKNOWN_NAME = "<field name=\"not_a_field\">item</field>"
  static let FIELD_MISSING_TEXT = "<field name=\"text_input\"></field>"

  static let VALUE_GOOD =
  "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"126\" />" +
  "</value>"
  static let VALUE_BAD_NAME =
  "<value name=\"not_a_name\">" +
    "<block type=\"output_foo\" id=\"126\"></block>" +
  "</value>"
  static let VALUE_NO_CHILD =
  "<value name=\"value_input\"></value>"
  static let VALUE_NO_OUTPUT =
  "<value name=\"value_input\">" +
    "<block type=\"no_output\" id=\"126\"></block>" +
  "</value>"
  static let VALUE_REPEATED =
  "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"126\"></block>" +
    "</value>" +
    "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"126\"></block>" +
  "</value>"

  static let STATEMENT_GOOD =
  "<statement name=\"NAME\">" +
    "<block type=\"frankenblock\" id=\"3\"></block>" +
  "</statement>"
  static let STATEMENT_NO_CHILD = "<statement name=\"NAME\"></statement>"
  static let STATEMENT_BAD_NAME =
  "<statement name=\"not_a_name\">" +
    "<block type=\"frankenblock\" id=\"3\"></block>" +
  "</statement>"
  static let STATEMENT_BAD_CHILD =
  "<statement name=\"NAME\">" +
    "<block type=\"no_output\" id=\"3\"></block>" +
  "</statement>"

  static let COMMENT_GOOD = "<comment pinned=\"true\" h=\"80\" w=\"160\">Calm</comment>"
  static let COMMENT_NO_TEXT = "<comment pinned=\"true\" h=\"80\" w=\"160\"></comment>"

  static let FRANKENBLOCK_DEFAULT_VALUES_START =
  "<field name=\"text_input\">something</field>" +
  "<field name=\"checkbox\">true</field>"
  static let FRANKENBLOCK_DEFAULT_VALUES_END =
  "<field name=\"dropdown\">OPTIONNAME1</field>" +
    "<field name=\"variable\">item</field>" +
    "<field name=\"angle\">90</field>" +
  "<field name=\"colour\">#ff0000</field>"
  static let FRANKENBLOCK_DEFAULT_VALUES =
  FRANKENBLOCK_DEFAULT_VALUES_START + FRANKENBLOCK_DEFAULT_VALUES_END

  class func assembleBlock(interior: String) -> String {
    return BLOCK_START + interior + BLOCK_END
  }
}
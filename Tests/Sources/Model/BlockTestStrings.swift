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
import Blockly

class BlockTestStrings {
  static let SIMPLE_BLOCK =
  "<block type=\"frankenblock\" id=\"3\" x=\"37\" y=\"13\">" +
    "<field name=\"text_input\">simple_block</field>" +
  "</block>"

  static let SIMPLE_SHADOW =
    "<shadow type=\"frankenblock\" id=\"SIMPLE_BLOCK\" x=\"37\" y=\"13\">" +
      "<field name=\"text_input\">item</field>" +
    "</shadow>"

  static let NO_BLOCK_TYPE =
  "<block id=\"4\" x=\"37\" y=\"13\">" +
    "<field name=\"text_input\">item</field>" +
  "</block>"

  static let NO_BLOCK_ID =
  "<block type=\"frankenblock\" x=\"-135\" y=\"-902\">" +
    "<field name=\"text_input\">no_block_id</field>" +
  "</block>"

  static let NO_BLOCK_POSITION =
  "<block type=\"frankenblock\" id=\"5\">" +
    "<field name=\"text_input\">no_block_position</field>" +
  "</block>"

  static let FIELD_HAS_NAME = "<field name=\"text_input\">field_has_name</field>"
  static let FIELD_MISSING_NAME = "<field>item</field>"
  static let FIELD_UNKNOWN_NAME = "<field name=\"not_a_field\">item</field>"
  static let FIELD_MISSING_TEXT = "<field name=\"text_input\"></field>"

  static let VALUE_GOOD =
  "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"6\" />" +
  "</value>"
  static let VALUE_BAD_NAME =
  "<value name=\"not_a_name\">" +
    "<block type=\"output_foo\" id=\"7\"></block>" +
  "</value>"
  static let VALUE_NO_CHILD =
  "<value name=\"value_input\"></value>"
  static let VALUE_NO_OUTPUT =
  "<value name=\"value_input\">" +
    "<block type=\"no_output\" id=\"8\"></block>" +
  "</value>"
  static let VALUE_REPEATED =
  "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"9\"></block>" +
    "</value>" +
    "<value name=\"value_input\">" +
    "<block type=\"output_foo\" id=\"10\"></block>" +
  "</value>"

  static let VALUE_SHADOW =
    "<value name=\"value_input\">" +
      "<shadow type=\"output_foo\" id=\"VALUE_GOOD\" />" +
    "</value>"
  static let VALUE_SHADOW_GOOD =
    "<value name=\"value_input\">" +
      "<shadow type=\"output_foo\" id=\"VALUE_SHADOW\" />" +
      "<block type=\"output_foo\" id=\"VALUE_REAL\" />" +
    "</value>"

  static let STATEMENT_GOOD =
  "<statement name=\"NAME\">" +
    "<block type=\"frankenblock\" id=\"11\"></block>" +
  "</statement>"
  static let STATEMENT_NO_CHILD = "<statement name=\"NAME\"></statement>"
  static let STATEMENT_BAD_NAME =
  "<statement name=\"not_a_name\">" +
    "<block type=\"frankenblock\" id=\"12\"></block>" +
  "</statement>"
  static let STATEMENT_BAD_CHILD =
  "<statement name=\"NAME\">" +
    "<block type=\"no_output\" id=\"13\"></block>" +
  "</statement>"
  static let STATEMENT_SHADOW_ONLY =
    "<statement name=\"NAME\">" +
      "<shadow type=\"frankenblock\" id=\"STATEMENT_SHADOW\">" +
      "</shadow>" +
    "</statement>"
  static let STATEMENT_REAL_AND_SHADOW =
    "<statement name=\"NAME\">" +
      "<shadow type=\"frankenblock\" id=\"STATEMENT_SHADOW\">" +
      "</shadow>" +
      "<block type=\"frankenblock\" id=\"STATEMENT_REAL\">" +
      "</block>" +
    "</statement>"

  static let NEXT_STATEMENT_GOOD =
    "<next>" +
      "<block type=\"frankenblock\" id=\"11\"></block>" +
    "</next>"
  static let NEXT_STATEMENT_SHADOW_ONLY =
    "<next>" +
      "<shadow type=\"frankenblock\" id=\"STATEMENT_SHADOW\" />" +
    "</next>"
  static let NEXT_STATEMENT_REAL_AND_SHADOW =
    "<next>" +
      "<shadow type=\"frankenblock\" id=\"STATEMENT_SHADOW\">" +
      "</shadow>" +
      "<block type=\"frankenblock\" id=\"STATEMENT_REAL\">" +
      "</block>" +
    "</next>"

  static let NESTED_SHADOW_GOOD =
    "<value name=\"value_input\">" +
      "<shadow type=\"simple_input_output\" id=\"SHADOW1\">" +
        "<value name=\"value\">" +
          "<shadow type=\"simple_input_output\" id=\"SHADOW2\" />" +
        "</value>" +
      "</shadow>" +
    "</value>" +
    "<next>" +
      "<shadow type=\"statement_no_input\" id=\"SHADOW3\" />" +
    "</next>"

  static let NESTED_SHADOW_BAD =
    "<value name=\"value_input\">" +
      "<shadow type=\"simple_input_output\" id=\"SHADOW1\">" +
        "<value name=\"value\">" +
          "<shadow type=\"simple_input_output\" id=\"SHADOW2\"/>"  +
          "<block type=\"simple_input_output\" id=\"BLOCK_INNER\"/>"  +
        "</value>" +
      "</shadow>" +
    "</value>"

  static let COMMENT_GOOD = "<comment pinned=\"true\" h=\"80\" w=\"160\">Calm</comment>"
  static let COMMENT_NO_TEXT = "<comment pinned=\"true\" h=\"80\" w=\"160\"></comment>"

  static let BLOCK_DELETABLE_TRUE = "<block type=\"frankenblock\" deletable=\"true\"></block>"
  static let BLOCK_DELETABLE_FALSE = "<block type=\"frankenblock\" deletable=\"false\"></block>"

  static let BLOCK_MOVABLE_TRUE = "<block type=\"frankenblock\" movable=\"true\"></block>"
  static let BLOCK_MOVABLE_FALSE = "<block type=\"frankenblock\" movable=\"false\"></block>"

  static let BLOCK_EDITABLE_TRUE = "<block type=\"frankenblock\" editable=\"true\"></block>"
  static let BLOCK_EDITABLE_FALSE = "<block type=\"frankenblock\" editable=\"false\"></block>"

  static let BLOCK_DISABLED_TRUE = "<block type=\"frankenblock\" disabled=\"true\"></block>"
  static let BLOCK_DISABLED_FALSE = "<block type=\"frankenblock\" disabled=\"false\"></block>"

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

  static let DUMMY_MUTATOR_VALUE = "<mutation id=\"dummy_mutator_xml_id\" />"

  class func assembleBlock(_ interior: String) -> String {
    return assembleComplexBlock(tag: "block", type: "frankenblock", id: "1",
                         position: WorkspacePoint(x: 37, y: 13), interior: interior)
  }

  class func assembleComplexBlock(
    tag: String, type: String, id: String?, position: WorkspacePoint?, interior: String)
    -> String
  {
    var attributes = "type=\"\(type)\""
    if let anID = id {
      attributes += " id=\"\(anID)\""
    }
    if let aPosition = position {
      attributes += " x=\"\(aPosition.x)\" y=\"\(aPosition.y)\""
    }
    return "<\(tag) \(attributes)>\(interior)</\(tag)>"
  }
}

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

/**
 List of all tags and attributes used for XML parsing/serialization.
 */
@objc(BKYXMLConstants)
@objcMembers internal class XMLConstants: NSObject {
  static let TAG_BLOCK = "block"
  static let TAG_SHADOW = "shadow"
  static let TAG_INPUT_VALUE = "value"
  static let TAG_INPUT_STATEMENT = "statement"
  static let TAG_NEXT_STATEMENT = "next"
  static let TAG_FIELD = "field"
  static let TAG_COMMENT = "comment"
  static let TAG_INPUTS_INLINE = "inline"
  static let TAG_DISABLED = "disabled"
  static let TAG_EDITABLE = "editable"
  static let TAG_DELETABLE = "deletable"
  static let TAG_MOVABLE = "movable"

  static let ATTRIBUTE_ID = "id"
  static let ATTRIBUTE_TYPE = "type"
  static let ATTRIBUTE_POSITION_X = "x"
  static let ATTRIBUTE_POSITION_Y = "y"
  static let ATTRIBUTE_NAME = "name"
}

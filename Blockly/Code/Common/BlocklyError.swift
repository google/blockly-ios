/*
* Copyright 2015 Google Inc. All Rights Reserved.
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
import SWXMLHash

/**
General error class for all Blockly errors.
*/
@objc(BKYBlocklyError)
public class BlocklyError: NSError {
  // MARK: - Static Properties

  /// Domain to use when throwing an error from this class
  public static let Domain = "com.google.blockly.Blockly"

  // MARK: - Enum - Code
  @objc
  public enum BKYBlocklyErrorCode: Int {
    case InvalidBlockDefinition = 100,
    ModelIllegalState = 101,
    LayoutNotFound = 200,
    LayoutIllegalState = 201,
    ConnectionManagerError = 210,
    ConnectionInvalid = 211,
    ViewNotFound = 300,
    JSONParsing = 400,
    JSONInvalidTypecast = 401,
    XMLParsing = 500,
    XMLUnknownBlock = 501
  }
  public typealias Code = BKYBlocklyErrorCode

  // MARK: - Initializers

  public init(_ code: Code, _ description: String) {
    super.init(
      domain: BlocklyError.Domain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey : description])
  }

  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }

  internal convenience init(_ code: Code, _ description: String, _ xml: XMLIndexer) {
    self.init(code, "\(description)\nXML:\n\(xml)")
  }
}

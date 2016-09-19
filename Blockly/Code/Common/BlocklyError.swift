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
import AEXML

/**
General error class for all Blockly errors.
*/
@objc(BKYBlocklyError)
public final class BlocklyError: NSError {
  // MARK: - Static Properties

  /// Domain to use when throwing an error from this class
  public static let Domain = "com.google.blockly.Blockly"

  // TODO:(#59) Clean up error codes to follow some sort of convention.

  // MARK: - Enum - Code
  @objc
  public enum BKYBlocklyErrorCode: Int {
    case invalidBlockDefinition = 100,
    workspaceExceedsCapacity = 150,
    layoutNotFound = 200,
    connectionManagerError = 210,
    connectionInvalid = 211,
    viewNotFound = 300,
    jsonParsing = 400,
    jsonInvalidTypecast = 401,
    xmlParsing = 500,
    xmlUnknownBlock = 501,
    fileNotFound = 600,
    fileNotReadable = 601,
    illegalState = 700,
    illegalArgument = 701,
    illegalOperation = 702
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

  internal convenience init(_ code: Code, _ description: String, _ xml: AEXMLElement) {
    self.init(code, "\(description)\nXML:\n\(xml)")
  }
}

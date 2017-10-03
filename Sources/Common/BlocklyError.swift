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
@objcMembers public final class BlocklyError: NSError {
  // MARK: - Static Properties

  /// Domain to use when throwing an error from this class
  public static let Domain = "com.google.blockly.Blockly"

  // TODO(#59): Clean up error codes to follow some sort of convention.

  // MARK: - Constants

  /// Signifies the type of error to be thrown by `BlocklyError`.
  @objc(BKYBlocklyErrorCode)
  public enum Code: Int {
    case
      /// This block is illegally defined.
      invalidBlockDefinition = 100,
      /// The workspace exceeds the given capacity, in number of blocks.
      workspaceExceedsCapacity = 150,
      /// The layout for a given model was not available to the factory.
      layoutNotFound = 200,
      /// The generic error for `ConnectionManager`.
      connectionManagerError = 210,
      /// Thrown when a `Connection` tries to connect to something that is invalid.
      connectionInvalid = 211,
      /// Thrown when a view can't be found.
      viewNotFound = 300,
      /// Thrown when json can't be correctly parsed.
      jsonParsing = 400,
      /// Thrown when json parsing results in an invalid typecast.
      jsonInvalidTypecast = 401,
      /// Thrown when an invalid argument is supplied in a JSON file.
      jsonInvalidArgument = 402,
      /// Thrown when JSON can't be correctly serialized.
      jsonSerialization = 403,
      /// Thrown when JSON data is missing.
      jsonDataMissing = 404,
      /// Thrown when xml can't be correctly parsed.
      xmlParsing = 500,
      /// Thrown when xml specifies a block that's unknown to the system.
      xmlUnknownBlock = 501,
      /// Thrown when a file can't be found.
      fileNotFound = 600,
      /// Thrown when a file can't be read.
      fileNotReadable = 601,
      /// Thrown when a property would render Blockly in an illegal state.
      illegalState = 700,
      /// Thrown when a property is set to something illegal.
      illegalArgument = 701,
      /// Thrown when an operation is called in an illegal manner.
      illegalOperation = 702
  }

  // MARK: - Initializers

  /**
   Initializes the error.

   - parameter code: The error `Code` that describes the error.
   - parameter description: The `String` description for this error.
   */
  internal init(_ code: Code, _ description: String) {
    super.init(
      domain: BlocklyError.Domain,
      code: code.rawValue,
      userInfo: [NSLocalizedDescriptionKey : description])
  }

  /**
   Initializes the error, with an XML element.

   - parameter code: The error `Code` that describes the error.
   - parameter description: The `String` description for this error.
   - parameter xml: The `AEXMLElement` with additional information about the error.
   */
  internal convenience init(_ code: Code, _ description: String, _ xml: AEXMLElement) {
    self.init(code, "\(description)\nXML:\n\(xml)")
  }

  /**
   :nodoc:
   */
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}

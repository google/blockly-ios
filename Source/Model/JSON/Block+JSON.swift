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

extension Block {
  // MARK: - Static Properties

  // JSON parameters
  fileprivate static let PARAMETER_TYPE = "type"
  // To maintain compatibility with Web Blockly, this value is spelled as "colour" and not "color"
  fileprivate static let PARAMETER_COLOR = "colour"
  fileprivate static let PARAMETER_OUTPUT = "output"
  fileprivate static let PARAMETER_PREVIOUS_STATEMENT = "previousStatement"
  fileprivate static let PARAMETER_NEXT_STATEMENT = "nextStatement"
  fileprivate static let PARAMETER_INPUTS_INLINE = "inputsInline"
  fileprivate static let PARAMETER_TOOLTIP = "tooltip"
  fileprivate static let PARAMETER_HELP_URL = "helpUrl"
  fileprivate static let PARAMETER_MESSAGE = "message"
  fileprivate static let PARAMETER_ARGUMENTS = "args"
  fileprivate static let PARAMETER_LAST_DUMMY_ALIGNMENT = "lastDummyAlign"
  fileprivate static let MESSAGE_PARAMETER_ALT = "alt"
  fileprivate static let MESSAGE_PARAMETER_TYPE = "type"

  // MARK: - Public

  /**
  Creates a new `Block.Builder` from a JSON dictionary.

  - Parameter json: The JSON dictionary.
  - Throws:
  `BlocklyError`: Occurs if there is a problem parsing the JSON dictionary (eg. insufficient data,
  malformed data, or contradictory data).
  - Returns: A new block builder.
  */
  public class func makeBuilder(json: [String: Any]) throws -> Block.Builder
  {
    if (json[PARAMETER_OUTPUT] != nil && json[PARAMETER_PREVIOUS_STATEMENT] != nil) {
      throw BlocklyError(.invalidBlockDefinition,
        "Must not have both an output and a previousStatement.")
    }

    // Build the block
    let blockName = (json[PARAMETER_TYPE] as? String) ?? ""
    let builder = Block.Builder(name: blockName)

    if let colorHue = json[PARAMETER_COLOR] as? CGFloat {
      builder.color = ColorHelper.makeColor(hue: colorHue)
    } else if let colorString = json[PARAMETER_COLOR] as? String,
        let color = ColorHelper.makeColor(rgb: colorString)
    {
      builder.color = color
    }

    if let output = json[PARAMETER_OUTPUT] {
      if let typeCheck = output as? String {
        try builder.setOutputConnection(enabled: true, typeChecks: [typeCheck])
      } else if let typeChecks = output as? [String] {
        try builder.setOutputConnection(enabled: true, typeChecks: typeChecks)
      } else {
        try builder.setOutputConnection(enabled: true)
      }
    }
    if let previousStatement = json[PARAMETER_PREVIOUS_STATEMENT] {
      if let typeCheck = previousStatement as? String {
        try builder.setPreviousConnection(enabled: true, typeChecks: [typeCheck])
      } else if let typeChecks = previousStatement as? [String] {
        try builder.setPreviousConnection(enabled: true, typeChecks: typeChecks)
      } else {
        try builder.setPreviousConnection(enabled: true)
      }
    }
    if let nextStatement = json[PARAMETER_NEXT_STATEMENT] {
      if let typeCheck = nextStatement as? String {
        try builder.setNextConnection(enabled: true, typeChecks: [typeCheck])
      } else if let typeChecks = nextStatement as? [String] {
        try builder.setNextConnection(enabled: true, typeChecks: typeChecks)
      } else {
        try builder.setNextConnection(enabled: true)
      }
    }
    if let inputsInline = json[PARAMETER_INPUTS_INLINE] as? Bool {
      builder.inputsInline = inputsInline
    }
    if let tooltip = json[PARAMETER_TOOLTIP] as? String {
      builder.tooltip = tooltip
    }
    if let helpURL = json[PARAMETER_HELP_URL] as? String {
      builder.helpURL = helpURL
    }

    // Interpolate any messages for the block
    var i = 0
    while true {
      guard let message = json[PARAMETER_MESSAGE + "\(i)"] as? String else {
        // No message found for next value of i, stop interpolating messages.
        break
      }
      let arguments = (json[PARAMETER_ARGUMENTS + "\(i)"] as? Array<[String: Any]>) ?? []
      let lastDummyAlignmentString =
        (json[PARAMETER_LAST_DUMMY_ALIGNMENT + "\(i)"] as? String) ?? ""
      let lastDummyAlignment =
        Input.Alignment(string: lastDummyAlignmentString) ?? Input.Alignment.left

      // TODO:(#38) If the message is a reference, we need to load the reference from somewhere
      // else (eg. localization)
      builder.inputBuilders += try interpolate(
        message: message, arguments: arguments, lastDummyAlignment: lastDummyAlignment)

      i += 1
    }

    return builder
  }

  // MARK: - Internal

  /**
  Interpolate a message description into an `Input.Builder` array.

  - Parameter message: Text contains interpolation tokens (%1, %2, ...) that match with fields or
  inputs defined in the arguments array. Each interpolation token should only appear once.
  - Parameter arguments: Array of arguments to be interpolated. It should match the same number of
  interpolation tokens in "message".
  - Parameter lastDummyAlignment: If a dummy input is added at the end, how should it be aligned?
  - Throws:
  `BlocklyError`: Thrown if the number of arguments doesn't match the number of interpolation tokens
  provided in the message, if any interpolation token was used more than once, if not all argument
  values were referenced by the interpolation tokens, or if an argument could not be parsed into an
  `Input` or `Field`.
  - Returns: An `Input.Builder` array
  */
  internal class func interpolate(message: String, arguments: Array<[String: Any]>,
    lastDummyAlignment: Input.Alignment) throws -> [Input.Builder]
  {
    let tokens = Block.tokenized(message: message)
    var processedIndices = [Bool](repeating: false, count: arguments.count)
    var tempFieldList = [Field]()
    var allInputBuilders = Array<Input.Builder>()

    for token in tokens {
      switch (token) {
      case let numberToken as Int:
        // This was an argument position
        let index = numberToken - 1
        if (index < 0 || index >= arguments.count) {
          throw BlocklyError(
            .invalidBlockDefinition, "Message index \"\(numberToken)\" out of range.")
        } else if (processedIndices[index]) {
          throw BlocklyError(
            .invalidBlockDefinition, "Message index \"\(numberToken)\" duplicated.")
        }

        var element: [String: Any]! = arguments[index]

        while (element != nil) {
          guard let argumentType = element[MESSAGE_PARAMETER_TYPE] as? String else {
            throw BlocklyError(
              .invalidBlockDefinition, "No type for argument \"\(numberToken)\".")
          }

          if let field = try Field.makeField(json: element) {
            // Add field to field list
            tempFieldList.append(field)
            break
          } else if let inputBuilder = Input.makeBuilder(json: element) {
            // Add current field list to input, and add input to input list
            inputBuilder.appendFields(tempFieldList)
            tempFieldList = []
            allInputBuilders.append(inputBuilder)
            break
          } else {
            // Try getting the fallback block if it exists
            bky_print("Unknown element type [\"\(argumentType)\"]")
            element = element[MESSAGE_PARAMETER_ALT] as? [String: Any]
          }
        }

        processedIndices[index] = true

      case var stringToken as String:
        // This was simply a string, append it if it's not empty
        stringToken = stringToken.trimmingCharacters(
          in: CharacterSet.whitespacesAndNewlines)
        if (stringToken != "") {
          tempFieldList.append(FieldLabel(name: "", text: stringToken))
        }

      default:
        // This shouldn't happen
        bky_print("Unexpected token, skipping: \(token)")
      }
    }

    // Throw an error if not every argument index was used
    let unusedIndices = processedIndices.filter({ $0 == false })
    if (unusedIndices.count > 0) {
      let unusedIndicesString = unusedIndices.map({ String($0) }).joined(separator: ",")
      throw BlocklyError(.invalidBlockDefinition,
        "Message did not reference the following indices: \(unusedIndicesString)")
    }

    // If there were leftover fields we need to add a dummy input to hold them.
    if (!tempFieldList.isEmpty) {
      let inputBuilder = Input.Builder(type: .dummy, name: "")
      inputBuilder.appendFields(tempFieldList)
      tempFieldList = []
      allInputBuilders.append(inputBuilder)
    }

    return allInputBuilders
  }

  /**
  Tokenize message, splitting text by text parameter positions (eg. "%1","%2",etc.). Tokens are
  returned in an array, where regular text is returned as a `String` and positions are returned
  as an `Int`.

  eg. `tokenized("Here is an example: %1\nAnd another example: %2.")`

  returns:

  `["Here is an example: ", 1, "\nAnd another example: ", 2]`

  - Parameter message: The message to tokenize
  - Returns: An array of tokens consisting of either `String` or `Int`
  */
  internal class func tokenized(message: String) -> [Any] {
    enum State {
      case baseCase, percentFound, percentAndDigitFound
    }

    var tokens = [Any]()
    var state = State.baseCase
    var currentTextToken = ""
    var currentNumber = 0
    var i = message.startIndex

    while i < message.endIndex {
      let character = message[i]

      switch (state) {
      case .baseCase:
        if (character == "%") {
          // Start escape.
          state = .percentFound
        } else {
          currentTextToken.append(character)
        }
      case .percentFound:
        if let number = Int(String(character)) {
          // Number found
          state = .percentAndDigitFound
          currentNumber = number
          if (currentTextToken != "") {
            tokens.append(currentTextToken)
            currentTextToken = ""
          }
        } else if (character == "%") {
          // Escaped %: %%
          currentTextToken.append(character)
          state = .baseCase
        } else {
          // Non-escaped % (eg. "%A"), just add it to the currentTextToken
          currentTextToken += "%\(character)"
          state = .baseCase
        }
      case .percentAndDigitFound:
        if let number = Int(String(character)) {
          // Multi-digit number.
          currentNumber = (currentNumber * 10) + number
        } else {
          // Not a number, add the current number token
          tokens.append(currentNumber)
          currentNumber = 0
          i = message.index(before: i)  // Parse this char again.
          state = .baseCase
        }
      }

      i = message.index(after: i)
    }

    // Process any remaining values
    switch state {
    case .baseCase:
      if (currentTextToken != "") {
        tokens.append(currentTextToken)
      }
    case .percentFound:
      tokens.append("%")
    case .percentAndDigitFound:
      tokens.append(currentNumber)
    }
    
    return tokens
  }
}

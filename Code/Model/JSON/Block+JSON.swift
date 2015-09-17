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
  // MARK: - Public

  /**
  Creates a new block from a JSON dictionary.

  - Parameter json: The JSON dictionary.
  - Parameter workspace: The workspace to associate with the new block.
  - Throws:
  [BlockError]: Occurs if there is a problem parsing the JSON dictionary (eg. insufficient data,
  malformed data, or contradictory data).
  - Returns: A new block.
  */
  public class func blockFromJSON(json: [String: AnyObject], workspace: Workspace) throws -> Block
  {
    if (json["output"] != nil && json["previousStatement"] != nil) {
      throw BlockError(.InvalidBlockDefinition,
        "Must not have both an output and a previousStatement.")
    }

    // Build the block
    let identifier = (json["id"] as? String) ?? ""
    let blockName = (json["name"] as? String) ?? ""
    let builder = Block.Builder(identifier: identifier, name: blockName, workspace: workspace)

    if let colourHue = json["colour"] as? Int {
      builder.colourHue = min(max(colourHue, 0), 360)
    }
    if let output = json["output"] {
      if let typeCheck = output as? String {
        try builder.setOutputConnectionEnabled(true, typeChecks: [typeCheck])
      } else if let typeChecks = output as? [String] {
        try builder.setOutputConnectionEnabled(true, typeChecks: typeChecks)
      } else {
        try builder.setOutputConnectionEnabled(true)
      }
    }
    if let previousStatement = json["previousStatement"] {
      if let typeCheck = previousStatement as? String {
        try builder.setPreviousConnectionEnabled(true, typeChecks: [typeCheck])
      } else if let typeChecks = previousStatement as? [String] {
        try builder.setPreviousConnectionEnabled(true, typeChecks: typeChecks)
      } else {
        try builder.setPreviousConnectionEnabled(true)
      }
    }
    if let nextStatement = json["nextStatement"] {
      if let typeCheck = nextStatement as? String {
        try builder.setNextConnectionEnabled(true, typeChecks: [typeCheck])
      } else if let typeChecks = nextStatement as? [String] {
        try builder.setNextConnectionEnabled(true, typeChecks: typeChecks)
      } else {
        try builder.setNextConnectionEnabled(true)
      }
    }
    if let inputsInline = json["inputsInline"] as? Bool {
      builder.inputsInline = inputsInline
    }
    if let tooltip = json["tooltip"] as? String {
      builder.tooltip = tooltip
    }
    if let helpURL = json["helpUrl"] as? String {
      builder.helpURL = helpURL
    }

    // Create the block
    let block = builder.build()

    // Interpolate any messages for the block
    for (var i = 0; ; i++) {
      guard let message = json["message\(i)"] as? String else {
        // No message found for next value of i, stop interpolating messages.
        break
      }
      let arguments = (json["args\(i)"] as? Array<[String: AnyObject]>) ?? []
      let lastDummyAlignmentString = (json["lastDummyAlign\(i)"] as? String) ?? ""
      let lastDummyAlignment =
      Input.Alignment(string: lastDummyAlignmentString) ?? Input.Alignment.Left

      // TODO:(vicng) If the message is a reference, we need to load the reference from somewhere
      // else (eg. localization)
      block.inputs += try block.interpolateMessage(
        message, arguments: arguments, lastDummyAlignment: lastDummyAlignment)
    }

    return block
  }

  // MARK: - Internal

  /**
  Interpolate a message description into an `Input` array.

  - Parameter message: Text contains interpolation tokens (%1, %2, ...) that match with fields or
  inputs defined in the arguments array. Each interpolation token should only appear once.
  - Parameter arguments: Array of arguments to be interpolated. It should match the same number of
  interpolation tokens in "message".
  - Parameter lastDummyAlignment: If a dummy input is added at the end, how should it be aligned?
  - Throws:
  [BlockError]: Thrown if the number of arguments doesn't match the number of interpolation tokens
  provided in the message, if any interpolation token was used more than once, if not all argument
  values were referenced by the interpolation tokens, or if an argument could not be parsed into an
  `Input` or `Field`.
  - Returns: An `Input` array
  */
  internal func interpolateMessage(message: String, arguments: Array<[String: AnyObject]>,
    lastDummyAlignment: Input.Alignment) throws -> [Input]
  {
    let tokens = Block.tokenizeMessage(message)
    var processedIndices = [Bool](count: arguments.count, repeatedValue: false)
    var tempFieldList = [Field]()
    var allInputs = [Input]()

    for token in tokens {
      switch (token) {
      case let numberToken as Int:
        // This was an argument position
        let index = numberToken - 1
        if (index < 0 || index >= arguments.count) {
          throw BlockError(
            .InvalidBlockDefinition, "Message index \"\(numberToken)\" out of range.")
        } else if (processedIndices[index]) {
          throw BlockError(
            .InvalidBlockDefinition, "Message index \"\(numberToken)\" duplicated.")
        }

        var element: [String: AnyObject]! = arguments[index]

        while (element != nil) {
          guard let argumentType = element["type"] as? String else {
            throw BlockError(
              .InvalidBlockDefinition, "No type for argument \"\(numberToken)\".")
          }

          if let field = try Field.fieldFromJSON(element) {
            // Add field to field list
            tempFieldList.append(field)
            break
          } else if let input = Input.inputFromJSON(element, sourceBlock: self) {
            // Add current field list to input, and add input to input list
            input.fields += tempFieldList
            tempFieldList = []
            allInputs.append(input)
            break
          } else {
            // Try getting the fallback block if it exists
            bky_print("Unknown element type [\"\(argumentType)\"]")
            element = element["alt"] as? [String: AnyObject]
          }
        }

        processedIndices[index] = true

      case var stringToken as String:
        // This was simply a string, append it if it's not empty
        stringToken = stringToken.stringByTrimmingCharactersInSet(
          NSCharacterSet.whitespaceAndNewlineCharacterSet())
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
      let unusedIndicesString = unusedIndices.map({ String($0) }).joinWithSeparator(",")
      throw BlockError(.InvalidBlockDefinition,
        "Message did not reference the following indices: \(unusedIndicesString)")
    }

    // If there were leftover fields we need to add a dummy input to hold them.
    if (!tempFieldList.isEmpty) {
      let input = Input(type: .Dummy, name: "", sourceBlock: self)
      input.fields += tempFieldList
      tempFieldList = []
      allInputs.append(input)
    }

    return allInputs
  }

  /**
  Tokenize message, splitting text by text parameter positions (eg. "%1","%2",etc.). Tokens are
  returned in an array, where regular text is returned as a `String` and positions are returned
  as an `Int`.

  eg. `tokenizeMessage("Here is an example: %1\nAnd another example: %2.")`

  returns:

  `["Here is an example: ", 1, "\nAnd another example: ", 2]`

  - Parameter message: The message to tokenize
  - Returns: An array of tokens consisting of either `String` or `Int`
  */
  internal class func tokenizeMessage(message: String) -> [NSObject] {
    enum State {
      case BaseCase, PercentFound, PercentAndDigitFound
    }

    var tokens = [NSObject]()
    var state = State.BaseCase
    var currentTextToken = ""
    var currentNumber = 0

    for (var i = message.startIndex; i < message.endIndex; i = i.successor()) {
      let character = message[i]

      switch (state) {
      case .BaseCase:
        if (character == "%") {
          // Start escape.
          state = .PercentFound
        } else {
          currentTextToken.append(character)
        }
      case .PercentFound:
        if let number = Int(String(character)) {
          // Number found
          state = .PercentAndDigitFound
          currentNumber = number
          if (currentTextToken != "") {
            tokens.append(currentTextToken)
            currentTextToken = ""
          }
        } else if (character == "%") {
          // Escaped %: %%
          currentTextToken.append(character)
          state = .BaseCase
        } else {
          // Non-escaped % (eg. "%A"), just add it to the currentTextToken
          currentTextToken += "%\(character)"
          state = .BaseCase
        }
      case .PercentAndDigitFound:
        if let number = Int(String(character)) {
          // Multi-digit number.
          currentNumber = (currentNumber * 10) + number
        } else {
          // Not a number, add the current number token
          tokens.append(currentNumber)
          currentNumber = 0
          i = i.predecessor();  // Parse this char again.
          state = .BaseCase;
        }
      }
    }

    // Process any remaining values
    switch state {
    case .BaseCase:
      if (currentTextToken != "") {
        tokens.append(currentTextToken)
      }
    case .PercentFound:
      tokens.append("%")
    case .PercentAndDigitFound:
      tokens.append(currentNumber)
    }
    
    return tokens
  }
}

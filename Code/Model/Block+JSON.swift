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

  @objc
  public class func blockFromJSONDictionary(
    json: Dictionary<String, AnyObject>, workspace: Workspace) throws -> Block
  {
    if (json["output"] != nil && json["previousStatement"] != nil) {
      throw BlockError(.InvalidBlockDefinition,
        "Must not have both an output and a previousStatement.")
    }

    let blockName = (json["name"] as? String) ?? ""

    let builder = Block.Builder(identifier: "", name: blockName, workspace: workspace)

    if let colourHue = json["colour"] as? Int {
      builder.colourHue = min(max(colourHue, 0), 360)
    }

    // Interpolate the message blocks.
    for (var i = 0; ; i++) {
      guard let message = json["message\(i)"] as? String else {
        // No message found for next value of i, stop interpolating messages.
        break
      }
      let arguments = (json["args\(i)"] as? [String]) ?? []
      let lastDummyAlign = (json["lastDummyAlign\(i)"] as? String) ?? ""

      interpolateMessage(message, arguments: arguments, lastDummyAlign: lastDummyAlign)
    }

    if let output = json["output"] as? String {
      // TODO(vicng): Parse output
    }

    if let previousStatement = json["previousStatement"] as? String {
      // TODO(vicng): Parse output
    }

    if let nextStatement = json["nextStatement"] as? String {
      // TODO(vicng): Parse output
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

    return builder.build()
  }

  // MARK: - Private

  private class func interpolateMessage(
    message: String, arguments: [String], lastDummyAlign: String)
  {
    // TODO(vicng): Implement this method

  }

  /**
  Tokenize message, splitting text by text parameter positions (eg. "%1","%2",etc.). Tokens are
  returned in an array, where regular text is returned as a |String| and positions are returned
  as an |Int|.

  eg. tokenizeMessage("Here is an example: %1\nAnd another example: %2.")

  returns: ["Here is an example: ",1,"\nAnd another example: ", 2]

  :param: message The message to tokenize
  :returns: An array of tokens consisting of either |String| or |Int|
  */
  internal class func tokenizeMessage(message: String) -> [NSObject] {
    enum State {
      case BaseCase, PercentFound, PercentAndDigitFound
    }

    var tokens: [NSObject] = []
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
          if (!currentTextToken.isEmpty) {
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
      if (!currentTextToken.isEmpty) {
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

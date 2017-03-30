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
  fileprivate static let PARAMETER_ARGUMENTS = "args"
  // To maintain compatibility with Web Blockly, this value is spelled as "colour" and not "color"
  fileprivate static let PARAMETER_COLOR = "colour"
  fileprivate static let PARAMETER_EXTENSIONS = "extensions"
  fileprivate static let PARAMETER_HELP_URL = "helpUrl"
  fileprivate static let PARAMETER_INPUTS_INLINE = "inputsInline"
  fileprivate static let PARAMETER_LAST_DUMMY_ALIGNMENT = "lastDummyAlign"
  fileprivate static let PARAMETER_MESSAGE = "message"
  fileprivate static let PARAMETER_MUTATOR = "mutator"
  fileprivate static let PARAMETER_NEXT_STATEMENT = "nextStatement"
  fileprivate static let PARAMETER_OUTPUT = "output"
  fileprivate static let PARAMETER_PREVIOUS_STATEMENT = "previousStatement"
  fileprivate static let PARAMETER_TOOLTIP = "tooltip"
  fileprivate static let PARAMETER_TYPE = "type"
  fileprivate static let MESSAGE_PARAMETER_ALT = "alt"
  fileprivate static let MESSAGE_PARAMETER_TYPE = "type"

  // MARK: - Public

  /**
   Creates a new `BlockBuilder` from a JSON dictionary.

   - parameter json: The JSON dictionary.
   - parameter mutators: Dictionary mapping names to `Mutator` objects. For any mutator
   name that has been defined in `json`, its corresponding mutator in this dictionary
   is added to the block builder.
   - parameter extensions: Dictionary mapping names to `BlockExtension` objects. For any extension
   name that has been defined in `json`, its corresponding block extension in this dictionary
   is added to the block builder.
   - throws:
   `BlocklyError`: Occurs if there is a problem parsing the JSON dictionary (eg. insufficient data,
   malformed data, or contradictory data). It also is thrown if a mutator (or extension) name has
   been defined in `json`, but no corresponding mapping could be found in `mutators`
   (or `extensions`).
   - returns: A new block builder.
   */
  public class func makeBuilder(json: [String: Any], mutators: [String: Mutator] = [:],
                                extensions: [String: BlockExtension] = [:]) throws -> BlockBuilder
  {
    if (json[PARAMETER_OUTPUT] != nil && json[PARAMETER_PREVIOUS_STATEMENT] != nil) {
      throw BlocklyError(.invalidBlockDefinition,
        "Must not have both an output and a previousStatement.")
    }

    // Build the block
    let blockName = (json[PARAMETER_TYPE] as? String) ?? ""
    let builder = BlockBuilder(name: blockName)

    let translatedColor = Block.translatedJSONValue(json[PARAMETER_COLOR])
    if let colorHue = translatedColor as? CGFloat {
      builder.color = ColorHelper.makeColor(hue: colorHue)
    } else if let colorString = translatedColor as? String {
      if let colorHue = NumberFormatter().number(from: colorString) {
        builder.color = ColorHelper.makeColor(hue: CGFloat(colorHue))
      } else if let color = ColorHelper.makeColor(rgb: colorString) {
        builder.color = color
      }
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
    if let tooltip = Block.translatedJSONValue(json[PARAMETER_TOOLTIP]) as? String {
      builder.tooltip = tooltip
    }
    if let helpURL = Block.translatedJSONValue(json[PARAMETER_HELP_URL]) as? String {
      builder.helpURL = helpURL
    }
    if let mutator = json[PARAMETER_MUTATOR] as? String {
      if let blockMutator = mutators[mutator] {
        builder.mutator = blockMutator.copyMutator()
      } else {
        throw BlocklyError(
          .jsonInvalidArgument, "No `Mutator` has been defined for \"\(mutator)\".")
      }
    }
    if let extensionNames = json[PARAMETER_EXTENSIONS] as? [String] {
      for extensionName in extensionNames {
        if let blockExtension = extensions[extensionName] {
          builder.extensions.append(blockExtension)
        } else {
          throw BlocklyError(
            .jsonInvalidArgument, "No `BlockExtension` has been defined for \"\(extensionName)\".")
        }
      }
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
  Interpolate a message description into an `InputBuilder` array.

  - parameter message: Text contains interpolation tokens (%1, %2, ...) that match with fields or
  inputs defined in the arguments array. Each interpolation token should only appear once.
  - parameter arguments: Array of arguments to be interpolated. It should match the same number of
  interpolation tokens in "message".
  - parameter lastDummyAlignment: If a dummy input is added at the end, how should it be aligned?
  - throws:
  `BlocklyError`: Thrown if the number of arguments doesn't match the number of interpolation tokens
  provided in the message, if any interpolation token was used more than once, if not all argument
  values were referenced by the interpolation tokens, or if an argument could not be parsed into an
  `Input` or `Field`.
  - returns: An `InputBuilder` array
  */
  internal class func interpolate(message: String, arguments: Array<[String: Any]>,
    lastDummyAlignment: Input.Alignment) throws -> [InputBuilder]
  {
    let tokens = Block.tokenizedMessage(message)
    var processedIndices = [Bool](repeating: false, count: arguments.count)
    var tempFieldList = [Field]()
    var allInputBuilders = Array<InputBuilder>()

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
      let inputBuilder = InputBuilder(type: .dummy, name: "")
      inputBuilder.appendFields(tempFieldList)
      tempFieldList = []
      allInputBuilders.append(inputBuilder)
    }

    return allInputBuilders
  }

  /**
   Given a value, returns the translated value of it if it's a `String`.
   If it isn't a `String`, this method simply returns back the original value.

   - parameter value: The JSON value to translate.
   - returns: If `value` is a `String`, returns the translated value of it. Otherwise, returns
   back `value`.
   */
  internal class func translatedJSONValue(_ value: Any?) -> Any? {
    guard let string = value as? String else {
      // Value isn't a string, return it
      return value
    }

    return translatedMessage(string)
  }

  /**
   Given a message, translates it by locating any keys of the form "%{<key>}" and replacing them
   with any translations found inside `TranslationManager.shared` that use that key.

   Additionally, for any keys that are successfully translated, this method recursively translates
   those values, if those values contain references to more keys of the form "%{<key>}".

   For example:
   ```
   TranslationManager.shared.loadTranslations([
     "bky_name": "Blockly",
     "bky_description": "This is the %{bky_name} library."
   ])
   Block.translatedMessage("%{bky_name}")              // Returns "Blockly"
   Block.translatedMessage("%{bky_description}")       // Returns "This is the Blockly library."
   Block.translatedMessage("%{non_existent_message}")  // Returns "%{non_existent_message}"
   ```

   - note: Translating a message with a key inside another key is not supported by this method
   (eg. `"%{bky_{%bky_key2}key1}"`). It's recommended that this situation is avoided as the outcome
   of this type of translation cannot be guaranteed.
   - parameter message: The message to translate.
   - returns: The translated version of `message`.
   */
  internal class func translatedMessage(_ message: String) -> String {
    var translation = message

    // Find all potential keys using the regex
    let matches = TranslationKeyFinder.shared.matches(
      in: translation, options: [], range: NSMakeRange(0, translation.utf16.count))

    // Perform each key translation in backwards order. This allows us to easily do key replacements
    // using the original ranges in the `matches`, without needing to keep track of range
    // offsets due to a key match being replaced.
    for match in matches.reversed() {
      guard
        match.numberOfRanges == 2,
        match.rangeAt(1).location != NSNotFound, // The first capture group is what contains the key
        let matchRange = bky_rangeFromNSRange(match.range, forString: translation),
        let keyRange = bky_rangeFromNSRange(match.rangeAt(1), forString: translation) else {
          continue
      }

      // Found a key, try to find a message for it.
      let key = translation.substring(with: keyRange)

      if let message = TranslationManager.shared.translation(forKey: key) {
        // A message was found for the key. The message itself may contain more key references,
        // so recursively translate this message before replacing the key in the original string.
        let translatedMessage = self.translatedMessage(message)
        translation.replaceSubrange(matchRange, with: translatedMessage)
      }
    }

    return translation
  }

  /**
  Tokenize message, splitting text by text parameter positions (eg. "%1","%2",etc.). Tokens are
  returned in an array, where regular text is returned as a `String` and positions are returned
  as an `Int`.

  eg. `tokenizedMessage("Here is an example: %1\nAnd another example: %2.")`

  returns:

  `["Here is an example: ", 1, "\nAnd another example: ", 2]`

  - parameter message: The message to tokenize
  - returns: An array of tokens consisting of either `String` or `Int`
  */
  internal class func tokenizedMessage(_ message: String) -> [Any] {
    enum State {
      case baseCase, percentFound, percentAndDigitFound
    }

    // Translate the message first to convert keys that may be present inside message
    // (eg. %{BKY_COLOUR_HUE})
    let translatedMessage = self.translatedMessage(message)
    var tokens = [Any]()
    var state = State.baseCase
    var currentTextToken = ""
    var currentNumber = 0
    var i = translatedMessage.startIndex

    while i < translatedMessage.endIndex {
      let character = translatedMessage[i]

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
          i = translatedMessage.index(before: i)  // Parse this char again.
          state = .baseCase
        }
      }

      i = translatedMessage.index(after: i)
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

/**
 Helper class for storing a regular expression used to parse translation keys during message
 translation.
 */
fileprivate class TranslationKeyFinder: NSRegularExpression {
  // Shared instance.
  fileprivate static var shared = TranslationKeyFinder()

  fileprivate init() {
    // This pattern matches: %{bky_test}, %{SOMEKEY}
    // Doesn't match: %%{bky_test}, %{0}, %1
    let pattern = "(?<!%)%\\{([a-z][a-z|0-9|_]*)\\}"
    do {
      try super.init(pattern: pattern, options: .caseInsensitive)
    } catch let error {
      fatalError("Could not initialize regular expression [`\(pattern)`]: \(error)")
    }
  }

  fileprivate required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
}

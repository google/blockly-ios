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

#import <Foundation/Foundation.h>

/// Options for specifying files that contain different types of JSON block definitions.
typedef NS_OPTIONS(NSInteger, BKYBlockJSONFile) {
  /// Option for specifying the file containing JSON definitions for default color blocks.
  BKYBlockJSONFileColorDefault CF_SWIFT_NAME(colorDefault) = 1 << 0,
  /// Option for specifying the file containing JSON definitions for default list blocks.
  BKYBlockJSONFileListDefault CF_SWIFT_NAME(listDefault) = 1 << 1,
  /// Option for specifying the file containing JSON definitions for default logic blocks.
  BKYBlockJSONFileLogicDefault CF_SWIFT_NAME(logicDefault) = 1 << 2,
  /// Option for specifying the file containing JSON definitions for default loop blocks.
  BKYBlockJSONFileLoopDefault CF_SWIFT_NAME(loopDefault) = 1 << 3,
  /// Option for specifying the file containing JSON definitions for default math blocks.
  BKYBlockJSONFileMathDefault CF_SWIFT_NAME(mathDefault) = 1 << 4,
  /// Option for specifying the file containing JSON definitions for default procedure blocks.
  BKYBlockJSONFileProcedureDefault CF_SWIFT_NAME(procedureDefault) = 1 << 5,
  /// Option for specifying the file containing JSON definitions for default text blocks.
  BKYBlockJSONFileTextDefault CF_SWIFT_NAME(textDefault) = 1 << 6,
  /// Option for specifying the file containing JSON definitions for default variable blocks.
  BKYBlockJSONFileVariableDefault CF_SWIFT_NAME(variableDefault) = 1 << 7,
  /// Option for specifying files containing JSON definitions for all default blocks.
  BKYBlockJSONFileAllDefault CF_SWIFT_NAME(allDefault) =
    BKYBlockJSONFileColorDefault |
    BKYBlockJSONFileListDefault |
    BKYBlockJSONFileLogicDefault |
    BKYBlockJSONFileLoopDefault |
    BKYBlockJSONFileMathDefault |
    BKYBlockJSONFileTextDefault |
    BKYBlockJSONFileVariableDefault |
    BKYBlockJSONFileProcedureDefault
} CF_SWIFT_NAME(BlockJSONFile);

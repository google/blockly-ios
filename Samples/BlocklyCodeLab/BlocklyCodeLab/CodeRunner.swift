/*
 * Copyright 2017 Google Inc. All Rights Reserved.
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

import Blockly
import JavaScriptCore
import UIKit

/**
 Runs JavaScript code.
 */
class CodeRunner {
  /// The JS context used for running the JS code.
  var context: JSContext!

  /// A background thread used for executing the JS code.
  let jsThread = DispatchQueue(label: "jsContext")

  init() {
    // Instantiate the JS context on a background thread.
    jsThread.async {
      self.context = JSContext()
      self.context?.exceptionHandler = { context, exception in
        let error = exception?.description ?? "unknown error"
        print("JS Error: \(error)")
      }

      // Expose `MusicMaker` as a bridged Javascript object
      self.context.setObject(MusicMaker.self, forKeyedSubscript: "MusicMaker" as NSString)
    }
  }

  public func runJavascriptCode(_ code: String, onFinish: @escaping () -> ()) {
    // Execute JS Code on the background thread
    jsThread.async {
      self.context.evaluateScript(code)

      DispatchQueue.main.async {
        onFinish()
      }
    }
  }
}

/**
 Protocol declaring all methods and properties that should be exposed to JS context.
 */
@objc protocol MusicMakerJSExports: JSExport {
  static func playSound(_ assetName: String)
}

@objc class MusicMaker: NSObject, MusicMakerJSExports {
  /// Keeps track of all sounds currently being played.
  static var audioPlayers = Set<AudioPlayer>()

  /// Maps a UUID to a condition lock. One entry is created every time a sound is played and it is
  /// removed playback completion.
  static var conditionLocks = [String: NSConditionLock]()

  /**
   Method that is exposed to the JS context, to play a specific sound.
 
   - parameter file: The sound file to play.
   */
  static func playSound(_ file: String) {
    guard let player = AudioPlayer(file: file) else {
      return
    }

    // Create a condition lock for this player so we don't return back to JS code until
    // the player has finished playing.
    let uuid = NSUUID().uuidString
    self.conditionLocks[uuid] = NSConditionLock(condition: 0)

    player.onFinish = { player, successfully in
      // Now that the player has finished, dispose of it and change the condition of the lock to
      // "1" to unblock the code below.
      self.conditionLocks[uuid]?.lock()
      self.audioPlayers.remove(player)
      self.conditionLocks[uuid]?.unlock(withCondition: 1)
    }

    if player.play() {
      // Hold a reference to the audio player so it doesn't go out of memory.
      self.audioPlayers.insert(player)

      // Wait for the condition lock to change to "1", which happens when the player finishes.
      // Once this happens, dispose of the lock and let control return back to the caller of
      // `playSound(...)` in the JS code.
      self.conditionLocks[uuid]?.lock(whenCondition: 1)
      self.conditionLocks[uuid]?.unlock()
      self.conditionLocks[uuid] = nil
    }
  }
}

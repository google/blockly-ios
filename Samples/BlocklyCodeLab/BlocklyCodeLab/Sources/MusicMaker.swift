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

import Foundation
import JavaScriptCore

/**
 Protocol declaring all methods and properties that should be exposed to a JS context.
 */
@objc protocol MusicMakerJSExports: JSExport {
  static func playSound(_ file: String)
}

/**
 Class exposed to a JS context.
 */
@objc @objcMembers class MusicMaker: NSObject, MusicMakerJSExports {
  /// Keeps track of all sounds currently being played.
  private static var audioPlayers = Set<AudioPlayer>()

  /// Maps a UUID to a condition lock. One entry is created every time a sound is played and it is
  /// removed playback completion.
  private static var conditionLocks = [String: NSConditionLock]()

  /**
   Play a specific sound. It blocks synchronously until playback of the sound has finished.

   This method is exposed to a JS context as `MusicMaker.playSound(_)`.

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

    player.completion = { player, successfully in
      // Now that playback has completed, dispose of the player and change the lock condition to
      // "1" to the code below `player.play()`.
      self.conditionLocks[uuid]?.lock()
      self.audioPlayers.remove(player)
      self.conditionLocks[uuid]?.unlock(withCondition: 1)
    }

    if player.play() {
      // Hold a reference to the audio player so it doesn't go out of memory.
      self.audioPlayers.insert(player)

      // Block this thread by waiting for the condition lock to change to "1", which happens when
      // playback is complete.
      // Once this happens, dispose of the lock and let control return back to the JS code (which
      // was the original caller of `MusicMaker.playSound(...)`).
      self.conditionLocks[uuid]?.lock(whenCondition: 1)
      self.conditionLocks[uuid]?.unlock()
      self.conditionLocks[uuid] = nil
    }
  }
}

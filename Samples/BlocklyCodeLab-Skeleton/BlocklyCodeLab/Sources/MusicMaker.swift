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

/**
 Class exposed to a JS context.
 */
class MusicMaker {
  /// Keeps track of all sounds currently being played.
  private static var audioPlayers = Set<AudioPlayer>()

  /**
   Play a specific sound.

   This method is exposed to a JS context as `MusicMaker.playSound(_)`.

   - parameter file: The sound file to play.
   */
  static func playSound(_ file: String) {
    guard let player = AudioPlayer(file: file) else {
      return
    }

    player.completion = { player, successfully in
      // Remove audio player so it is deallocated
      self.audioPlayers.remove(player)
    }

    if player.play() {
      // Hold a reference to the audio player so it doesn't go out of memory.
      self.audioPlayers.insert(player)
    }
  }
}

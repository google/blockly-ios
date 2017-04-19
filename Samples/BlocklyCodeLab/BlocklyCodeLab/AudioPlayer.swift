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

import AVFoundation
import UIKit

/**
 Audio player wrapper used for playing a single file.
 */
class AudioPlayer: NSObject {

  /// The underlying `AVAudioPlayer`.
  private let player: AVAudioPlayer

  /// Closure that is called when the audio player has finished playing the file. The `Bool` flag
  /// flag represents if playback completed successfully.
  public var completion: ((_ player: AudioPlayer, _ successfully: Bool) -> ())?

  // MARK: - Initializers

  /**
   Initializes an audio player wrapper for a given audio file.

   - parameter file: The audio file.
   - returns: If `file` could be loaded successfully, return an instance of `AudioPlayer`.
   If not, `nil` is returned.
   */
  public init?(file: String) {
    guard let path = Bundle.main.path(forResource: file, ofType: "") else {
      print("Could not find the sound effect for '\(file)'.")
      return nil
    }

    do {
      let pathURL = URL(fileURLWithPath: path)
      player = try AVAudioPlayer(contentsOf: pathURL)
      super.init()

      player.delegate = self
      player.prepareToPlay()
    } catch let error {
      print("Could not create AVAudioPlayer for '\(file)': \(error)")
      return nil
    }
  }

  // MARK: - Playback

  /**
   Plays the loaded audio file.

   - returns: `true` if the file could be played. `false` otherwise.
   */
  func play() -> Bool {
    return player.play()
  }
}

extension AudioPlayer: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    completion?(self, flag)
  }

  public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
    completion?(self, false)
  }
}

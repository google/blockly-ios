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
 Simple audio player wrapper used for playing a single file.
 */
class AudioPlayer: NSObject {

  public var onFinish: ((Bool) -> ())?

  private let player: AVAudioPlayer

  // MARK: - Initializers

  public init?(file: String) {
    guard let sound = NSDataAsset(name: file) else {
      print("Could not find the sound effect for '\(file)' in `Assets.xcassets`.")
      return nil
    }

    do {
      player = try AVAudioPlayer(data: sound.data, fileTypeHint: AVFileTypeMPEGLayer3)
      super.init()

      player.delegate = self
      player.prepareToPlay()
    } catch let error {
      print("Could not create AVAudioPlayer for '\(file)': \(error)")
      return nil
    }
  }

  // MARK: - Playback

  func play() -> Bool {
    return player.play()
  }
}

extension AudioPlayer: AVAudioPlayerDelegate {
  func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
    onFinish?(flag)
  }
}

//
//  AudioPlayer.swift
//  BlocklyCodeLab
//
//  Created by Cory Diers on 4/17/17.
//  Copyright © 2017 Google. All rights reserved.
//

import AVFoundation
import Foundation

class AudioPlayer {

  private var audioPlayers: [String:AVAudioPlayer] = [String:AVAudioPlayer]()
  private let effectNames = ["cheer",
                             "fart",
                             "fire_bow",
                             "lightbulb",
                             "party_horn",
                             "string_tension"]

  static let sharedInstance = AudioPlayer()

  public init() {
    for name in effectNames {
      guard let path = Bundle.main.path(forResource: name, ofType: "mp3") else {
        print("Could not find the sound effect for " + name + ".")
        return
      }
      let pathURL = URL(fileURLWithPath: path)
      audioPlayers[name] = try? AVAudioPlayer(contentsOf: pathURL)
    }
  }

  public func play(_ name: String) {
    guard var player = audioPlayers[name] else {
      print("Failed to play " + name + " sound, could not find audio player.")
      return
    }
    if player.isPlaying {
      player.stop()
      guard let path = Bundle.main.path(forResource: name, ofType: "mp3") else {
        print("Could not find the sound effect for " + name + ".")
        return
      }
      let pathURL = URL(fileURLWithPath: path)
      audioPlayers[name] = try? AVAudioPlayer(contentsOf: pathURL)
      guard let newPlayer = audioPlayers[name] else {
        print("Failed to play " + name + " sound, could not create audio player.")
        return
      }
      player = newPlayer
    }

    player.prepareToPlay()
    player.play()
  }
}

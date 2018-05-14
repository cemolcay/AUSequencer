//
//  ViewController.swift
//  AUSequencer
//
//  Created by Cem Olcay on 3.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import UIKit
import AudioKitUI
import AudioKit

class ViewController: UIViewController {
  var sequencer = StepSequencer()

  override func viewDidLoad() {
    super.viewDidLoad()
    AudioEngineManager.shared.start()
    AudioEngineManager.shared.renderCallback = renderCallback

  }

  @IBAction func playButtonPressed(sender: UIButton) {
    AudioEngineManager.shared.isPlaying = !AudioEngineManager.shared.isPlaying
    sender.setTitle(AudioEngineManager.shared.isPlaying ? "Stop" : "Play", for: .normal)
  }

  func renderCallback(bpm: Double) {
    guard AudioEngineManager.shared.isPlaying else { return }
  }
}

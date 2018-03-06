//
//  AudioEngine.swift
//  ArpBud
//
//  Created by Cem Olcay on 5.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import Foundation
import AudioKit

class AudioEngine {
  static let shared = AudioEngine()
  var engine: AudioEngineManager!

  func start() {
    #if DEBUG
      AKSettings.enableLogging = true
    #else
      AKSettings.enableLogging = false
    #endif

    engine = AudioEngineManager(
      tempo: 120,
      timelineTap: timelineTapBlock,
      completionHandler: nil)

    engine.linkStartStopStateChangedBlock = { on in
      print("link start stop state changed \(on)")
    }

    engine.coreMIDIReceivingEnabledBlock = { isEnabled in
      MIDIManager.shared.coreMIDIReceivingEnabled = isEnabled
    }

    engine.coreMIDISendingEnabledBlock = { isEnabled in
      MIDIManager.shared.coreMIDISendingEnabled = isEnabled
    }

    engine.midiReceiverBlock = MIDIManager.shared.midiDidReceive
    engine.start()
  }

  var linkSettingsController: ABLLinkSettingsViewController? {
    guard let linkRef = engine.linkRef else { return nil }
    return ABLLinkSettingsViewController.instance(linkRef)
  }

  func timelineTapBlock(
    timeline: UnsafeMutablePointer<AKTimeline>,
    timestamp: UnsafeMutablePointer<AudioTimeStamp>,
    offset: UInt32,
    frames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>) {
    return
  }
}

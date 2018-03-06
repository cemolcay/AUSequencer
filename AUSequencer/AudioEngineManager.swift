//
//  AudioEngineManager.swift
//  ArpBud
//
//  Created by Cem Olcay on 5.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import Foundation
import AudioKit

class AudioEngineManager {
  static let shared = AudioEngineManager()
  private(set) var engine: AudioEngine!
  var isPlaying = false

  var renderCallback: ((_ beat: Double) -> Void)?
  var linkTempoCallback: ((_ bpm: Double) -> Void)?

  func start() {
    #if DEBUG
      AKSettings.enableLogging = true
    #else
      AKSettings.enableLogging = false
    #endif

    engine = AudioEngine(
      tempo: 120,
      renderCallback: { [weak self] beat in
        self?.renderCallback?(beat)
      },
      completionHandler: nil)

    engine.linkStartStopStateChangedBlock = { [weak self] on in
      self?.isPlaying = on
    }

    engine.linkTempoChangedBlock = { [weak self] bpm in
      self?.linkTempoCallback?(bpm)
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
}

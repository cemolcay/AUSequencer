//
//  AKMIDISequencer.swift
//  AUSequencer
//
//  Created by Cem Olcay on 3.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import Foundation
import AudioKit

open class AKMIDISequencer: AKNode, AKToggleable, AKComponent {
  public typealias AKAudioUnitType = AKMIDISequencerAudioUnit
  /// Four letter unique description of the node
  public static let ComponentDescription = AudioComponentDescription(generator: "seqc")

  // MARK: - Properties

  private var internalAU: AKAudioUnitType?
  private var token: AUParameterObserverToken?

  /// Tells whether the node is processing (ie. started, playing, or active)
  @objc open dynamic var isStarted: Bool {
    return internalAU?.isPlaying ?? false
  }

  // MARK: - Initialization

  /// Initialize the oscillator with defaults
  public override init() {
    _Self.register()

    super.init()
    AVAudioUnit._instantiate(with: _Self.ComponentDescription) { [weak self] avAudioUnit in
      guard let strongSelf = self else {
        AKLog("Error: self is nil")
        return
      }
      strongSelf.avAudioNode = avAudioUnit
      strongSelf.internalAU = avAudioUnit.auAudioUnit as? AKAudioUnitType
    }
  }

  /// Function to start, play, or activate the node, all do the same thing
  @objc open func start() {
    internalAU?.start()
  }

  /// Function to stop or bypass the node, both are equivalent
  @objc open func stop() {
    internalAU?.stop()
  }
}

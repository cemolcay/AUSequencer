//
//  AKMIDISequencerAudioUnit.swift
//  AUSequencer
//
//  Created by Cem Olcay on 5.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import Foundation
import AudioKit

public class AKMIDISequencerAudioUnit: AKGeneratorAudioUnitBase {
  var pDSP: UnsafeMutableRawPointer?

  public override func initDSP(withSampleRate sampleRate: Double,
                               channelCount count: AVAudioChannelCount) -> UnsafeMutableRawPointer! {
    pDSP = createAKMIDISequencerDSP(Int32(count), sampleRate)
    return pDSP
  }

  override init(componentDescription: AudioComponentDescription,
                options: AudioComponentInstantiationOptions = []) throws {
    try super.init(componentDescription: componentDescription, options: options)
  }

  public override var canProcessInPlace: Bool { return true; }
}

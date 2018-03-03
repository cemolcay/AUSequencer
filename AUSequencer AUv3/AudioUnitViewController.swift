//
//  AudioUnitViewController.swift
//  AUSequencer AUv3
//
//  Created by Cem Olcay on 3.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import CoreAudioKit

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if audioUnit == nil {
            return
        }
        
        // Get the parameter tree and add observers for any parameters that the UI needs to keep in sync with the AudioUnit
    }
    
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try AKMIDISequencerAudioUnit(componentDescription: componentDescription, options: [])
        
        return audioUnit!
    }
    
}

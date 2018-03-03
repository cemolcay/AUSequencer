//
//  AUSequencer_AUv3AudioUnit.h
//  AUSequencer AUv3
//
//  Created by Cem Olcay on 3.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import <AudioToolbox/AudioToolbox.h>
#include "ABLLink.h"
#include "ABLLinkUtils.h"
#include "ABLLinkSettingsViewController.h"

// Define parameter addresses.
extern const AudioUnitParameterID myParam1;

@interface AKMIDISequencerAudioUnit : AUAudioUnit

@end

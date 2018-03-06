//
//  AudioEngineManager.h
//  ArpBud
//
//  Created by Cem Olcay on 6.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
#include "AudioKit/AudioKit.h"
#import "ABLLink.h"
#import "Audiobus.h"

typedef void (^AudioEngineInitCompletionHandler)(AudioUnit audioUnit);
typedef void (^AudioEngineRenderCallback)(double beat);
typedef void (^ABCoreMIDIEnableBlock)(BOOL isEnabled);
typedef void (^LinkStartStopStateChanged)(BOOL on);
typedef void (^LinkTempoChanged)(Float64 bpm);

@interface AudioEngine : NSObject

@property (nonatomic) Float64 bpm;
@property (readonly, nonatomic) Float64 beatTime;
@property (nonatomic) Float64 quantum;
@property (nonatomic) BOOL isPlaying;
@property (readonly, nonatomic) BOOL isLinkEnabled;
@property (readonly, nonatomic) ABLLinkRef linkRef;
@property (nonatomic) ABAudiobusController *audiobusController;
@property (nonatomic) ABMIDISenderPort *midiSenderPort;
@property (copy) ABMIDIReceiverPortMIDIReceiverBlock midiReceiverBlock;
@property (copy) ABCoreMIDIEnableBlock coreMIDISendingEnabledBlock;
@property (copy) ABCoreMIDIEnableBlock coreMIDIReceivingEnabledBlock;
@property (copy) LinkStartStopStateChanged linkStartStopStateChangedBlock;
@property (copy) LinkTempoChanged linkTempoChangedBlock;
@property (copy) AudioEngineRenderCallback renderCallbackBlock;

- (instancetype)initWithTempo:(Float64)bpm
               renderCallback:(AudioEngineRenderCallback)renderCallbackBlock
            completionHandler:(AudioEngineInitCompletionHandler)completionHandler;
- (void)start;
- (void)stop;

@end


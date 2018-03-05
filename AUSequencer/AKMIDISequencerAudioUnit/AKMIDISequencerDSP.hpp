//
//  AKMIDISequencerDSP.hpp
//  AUSequencer
//
//  Created by Cem Olcay on 5.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#pragma once

#import <Foundation/Foundation.h>

#ifndef __cplusplus

void* createAKMIDISequencerDSP(int nChannels, double sampleRate);

#else

#import "AudioKit/AudioKit.h"

struct AKMIDISequencerDSP : AKDSPBase
{
  AKMIDISequencerDSP();
  void init(int nChannels, double sampleRate) override;
  void deinit() override;

  void setParameter(uint64_t address, float value, bool immediate) override;
  float getParameter(uint64_t address) override;

  void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override;
};

#endif

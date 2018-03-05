//
//  AKMIDISequnecerDSP.mm
//  AUSequencer
//
//  Created by Cem Olcay on 5.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#include "AKMIDISequencerDSP.hpp"

extern "C" void* createAKMIDISequencerDSP(int nChannels, double sampleRate) {
  return new AKMIDISequencerDSP();
}

AKMIDISequencerDSP::AKMIDISequencerDSP() {}

void AKMIDISequencerDSP::init(int nChannels, double sampleRate) {
  AKDSPBase::init(nChannels, sampleRate);
}

void AKMIDISequencerDSP::deinit() {}

void AKMIDISequencerDSP::setParameter(uint64_t address, float value, bool immediate) {}

float AKMIDISequencerDSP::getParameter(uint64_t address) {
  return 0;
}

void AKMIDISequencerDSP::process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) {
  return;
}

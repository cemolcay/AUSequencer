//
//  AudioEngine.m
//  ArpBud
//
//  Created by Cem Olcay on 6.03.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

#import "AudioEngine.h"
#include <libkern/OSAtomic.h>
#include <mach/mach_time.h>

#define INVALID_BEAT_TIME DBL_MIN
#define INVALID_BPM DBL_MIN

#define AUDIOBUS_API_KEY @"H4sIAAAAAAAAA52QzU7DMBCEXyXac6gTuCDfirjkgOCOUeWfpbXaONbai4iqvDtWiEShhQNHzzfeGc0R8D16GkE2NRgO7oCboHsECWuKd+ygBqbDJtkdzqqmaNhdtatmpdn5wXCSSihRfHGgnEA+HyGPcfaaflv0b/eqh+6+qx45F+AwWfIx+yFc5InNcqk8eh34VdvMhPSpvCGl+Wsz1aeZdDmzC39GzvhfiUy+sJ13DgvKxPgjX1brZarqqWz0S41z11ebsvr2vJG12J+2aqeXGrwrRIlFTErscVTi5vq2hekDpqNLme4BAAA=:F8U1y9D3NHcejvlN2d5hlnT/m9FATINsRPLjx1Mxcc4VPoD3jbTvXvj1imHRvvKCqy2S/hT1BMHu3eyEGrQsqVFf4tyDCtmvnkEXhFTZ9DknBvHnHAapGMeja1rtW0Jv"

static OSSpinLock lock;
static dispatch_once_t audiobusInitOnceToken;

/*
 * Structure that stores engine-related data that can be changed from
 * the main thread.
 */
typedef struct {
  UInt64 outputLatency; // Hardware output latency in HostTime
  Float64 resetToBeatTime;
  BOOL requestStart;
  BOOL requestStop;
  Float64 proposeBpm;
  Float64 quantum;
} EngineData;

/*
 * Structure that stores all data needed by the audio callback.
 */
typedef struct {
  ABLLinkRef ablLink;
  // Shared between threads. Only write when engine not running.
  Float64 sampleRate;
  // Shared between threads. Only write when engine not running.
  Float64 secondsToHostTime;
  // Shared between threads. Written by the main thread and only
  // read by the audio thread when doing so will not block.
  EngineData sharedEngineData;
  // Copy of sharedEngineData owned by audio thread.
  EngineData localEngineData;
  // Owned by audio thread
  UInt64 timeAtLastClick;
  // Owned by audio thread
  BOOL isPlaying;
} LinkData;

typedef struct {
  LinkData *linkRef;
  AudioEngineRenderCallback callback;
} AudioEngineRenderCallbackData;

/*
 * Pull data from the main thread to the audio thread if lock can be
 * obtained. Otherwise, just use the local copy of the data.
 */
static void pullEngineData(LinkData* linkData, EngineData* output) {
  // Always reset the signaling members to their default state
  output->resetToBeatTime = INVALID_BEAT_TIME;
  output->proposeBpm = INVALID_BPM;
  output->requestStart = NO;
  output->requestStop = NO;

  // Attempt to grab the lock guarding the shared engine data but
  // don't block if we can't get it.
  if (OSSpinLockTry(&lock)) {
    // Copy non-signaling members to the local thread cache
    linkData->localEngineData.outputLatency =
    linkData->sharedEngineData.outputLatency;
    linkData->localEngineData.quantum = linkData->sharedEngineData.quantum;

    // Copy signaling members directly to the output and reset
    output->resetToBeatTime = linkData->sharedEngineData.resetToBeatTime;
    linkData->sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;

    output->requestStart = linkData->sharedEngineData.requestStart;
    linkData->sharedEngineData.requestStart = NO;

    output->requestStop = linkData->sharedEngineData.requestStop;
    linkData->sharedEngineData.requestStop = NO;

    output->proposeBpm = linkData->sharedEngineData.proposeBpm;
    linkData->sharedEngineData.proposeBpm = INVALID_BPM;

    OSSpinLockUnlock(&lock);
  }

  // Copy from the thread local copy to the output. This happens
  // whether or not we were able to grab the lock.
  output->outputLatency = linkData->localEngineData.outputLatency;
  output->quantum = linkData->localEngineData.quantum;
}

static OSStatus audioCallback(
                              void *inRefCon,
                              AudioUnitRenderActionFlags *flags,
                              const AudioTimeStamp *inTimeStamp,
                              UInt32 inBusNumber,
                              UInt32 inNumberFrames,
                              AudioBufferList *ioData) {
#pragma unused(inBusNumber, flags)

  // First clear buffers
  for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
    memset(ioData->mBuffers[i].mData, 0, inNumberFrames * sizeof(SInt16));
  }

  AudioEngineRenderCallbackData *data = (AudioEngineRenderCallbackData *)inRefCon;
  LinkData *linkData = data->linkRef;

  // Get a copy of the current link session state.
  const ABLLinkSessionStateRef sessionState =
  ABLLinkCaptureAudioSessionState(linkData->ablLink);

  // Get a copy of relevant engine parameters.
  EngineData engineData;
  pullEngineData(linkData, &engineData);

  // The mHostTime member of the timestamp represents the time at
  // which the buffer is delivered to the audio hardware. The output
  // latency is the time from when the buffer is delivered to the
  // audio hardware to when the beginning of the buffer starts
  // reaching the output. We add those values to get the host time
  // at which the first sample of this buffer will reach the output.
  const UInt64 hostTimeAtBufferBegin =
  inTimeStamp->mHostTime + engineData.outputLatency;

  if (engineData.requestStart && !ABLLinkIsPlaying(sessionState)) {
    // Request starting playback at the beginning of this buffer.
    ABLLinkSetIsPlaying(sessionState, YES, hostTimeAtBufferBegin);
  }

  if (engineData.requestStop && ABLLinkIsPlaying(sessionState)) {
    // Request stopping playback at the beginning of this buffer.
    ABLLinkSetIsPlaying(sessionState, NO, hostTimeAtBufferBegin);
  }

  if (!linkData->isPlaying && ABLLinkIsPlaying(sessionState)) {
    // Reset the session state's beat timeline so that the requested
    // beat time corresponds to the time the transport will start playing.
    // The returned beat time is the actual beat time mapped to the time
    // playback will start, which therefore may be less than the requested
    // beat time by up to a quantum.
    ABLLinkRequestBeatAtStartPlayingTime(sessionState, 0., engineData.quantum);
    linkData->isPlaying = YES;
  }
  else if(linkData->isPlaying && !ABLLinkIsPlaying(sessionState)) {
    linkData->isPlaying = NO;
  }

  // Handle a tempo proposal
  if (engineData.proposeBpm != INVALID_BPM) {
    // Propose that the new tempo takes effect at the beginning of
    // this buffer.
    ABLLinkSetTempo(sessionState, engineData.proposeBpm, hostTimeAtBufferBegin);
  }

  ABLLinkCommitAudioSessionState(linkData->ablLink, sessionState);

  // Send beat callback
  if (data->callback) {
    data->callback(ABLLinkBeatAtTime(sessionState, hostTimeAtBufferBegin, 4));
  }

  return noErr;
}

static void onSessionTempoChanged(Float64 bpm, void* context) {
  AudioEngine *engine = (__bridge AudioEngine *)context;
  [engine setBpm:bpm];
  if (engine.linkTempoChangedBlock) {
    engine.linkTempoChangedBlock(bpm);
  }
}

static void onStartStopStateChanged(bool on, void* context) {
  AudioEngine* engine = (__bridge AudioEngine *)context;
  if (engine.linkStartStopStateChangedBlock) {
    engine.linkStartStopStateChangedBlock(on);
  }
}

# pragma mark - AudioEngine

@interface AudioEngine() {
  AudioUnit _ioUnit;
  LinkData _linkData;
  AudioEngineRenderCallbackData _renderCallbackData;
}
@end

@implementation AudioEngine

# pragma mark - Transport
- (BOOL)isPlaying {
  const ABLLinkSessionStateRef sessionState = ABLLinkCaptureAppSessionState(_linkData.ablLink);
  return ABLLinkIsPlaying(sessionState);
}

- (void)setIsPlaying:(BOOL)isPlaying {
  OSSpinLockLock(&lock);
  if (isPlaying) {
    _linkData.sharedEngineData.requestStart = YES;
  }
  else {
    _linkData.sharedEngineData.requestStop = YES;
  }
  OSSpinLockUnlock(&lock);
}

- (Float64)bpm {
  return ABLLinkGetTempo(ABLLinkCaptureAppSessionState(_linkData.ablLink));
}

- (void)setBpm:(Float64)bpm {
  OSSpinLockLock(&lock);
  _linkData.sharedEngineData.proposeBpm = bpm;
  OSSpinLockUnlock(&lock);
}

- (Float64)beatTime {
  return ABLLinkBeatAtTime(
                           ABLLinkCaptureAppSessionState(_linkData.ablLink),
                           mach_absolute_time(),
                           self.quantum);
}

- (Float64)quantum {
  return _linkData.sharedEngineData.quantum;
}

- (void)setQuantum:(Float64)quantum {
  OSSpinLockLock(&lock);
  _linkData.sharedEngineData.quantum = quantum;
  OSSpinLockUnlock(&lock);
}

- (BOOL)isLinkEnabled {
  return ABLLinkIsEnabled(_linkData.ablLink);
}

- (ABLLinkRef)linkRef {
  return _linkData.ablLink;
}

# pragma mark - Handle AVAudioSession changes
- (void)handleRouteChange:(NSNotification *)notification {
#pragma unused(notification)
  const UInt64 outputLatency =
  _linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency;
  OSSpinLockLock(&lock);
  _linkData.sharedEngineData.outputLatency = outputLatency;
  OSSpinLockUnlock(&lock);
}

static void StreamFormatCallback(
                                 void *inRefCon,
                                 AudioUnit inUnit,
                                 AudioUnitPropertyID inID,
                                 AudioUnitScope inScope,
                                 AudioUnitElement inElement)
{
#pragma unused(inID)
  AudioEngine *engine = (__bridge AudioEngine *)inRefCon;

  if(inScope == kAudioUnitScope_Output && inElement == 0) {
    AudioStreamBasicDescription asbd;
    UInt32 dataSize = sizeof(asbd);
    OSStatus result = AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
                                           kAudioUnitScope_Output, 0, &asbd, &dataSize);
    NSCAssert2(
               result == noErr,
               @"Get Stream Format failed. Error code: %d '%.4s'",
               (int)result,
               (const char *)(&result));

    const Float64 oldSampleRate = engine->_linkData.sampleRate;
    if (oldSampleRate != asbd.mSampleRate) {
      [engine stop];
      [engine deallocAudioEngine];
      engine->_linkData.sampleRate = asbd.mSampleRate;
      [engine setupAudioEngine];
      [engine start];
    }
  }
}

# pragma mark - create and delete engine
- (instancetype)initWithTempo:(Float64)bpm
               renderCallback:(AudioEngineRenderCallback)renderCallbackBlock
            completionHandler:(AudioEngineInitCompletionHandler)completionHandler {

  if ([super init]) {
    self.renderCallbackBlock = renderCallbackBlock;

    [self initLinkData:bpm];
    [self setupAudioEngine];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:[AVAudioSession sharedInstance]];

    if (completionHandler) {
      completionHandler(_ioUnit);
    }
  }
  return self;
}

- (void)dealloc {
  if (_ioUnit) {
    OSStatus result = AudioComponentInstanceDispose(_ioUnit);
    NSCAssert2(
               result == noErr,
               @"Could not dispose Audio Unit. Error code: %d '%.4s'",
               (int)result,
               (const char *)(&result));
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:@"AVAudioSessionRouteChangeNotification"
                                                object:[AVAudioSession sharedInstance]];
  ABLLinkDelete(_linkData.ablLink);
}

# pragma mark - start and stop engine
- (void)start {
  NSError *error = nil;
  if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
    NSLog(@"Couldn't activate audio session: %@", error);
  }

  OSStatus result = AudioOutputUnitStart(_ioUnit);
  NSCAssert2(
             result == noErr,
             @"Could not start Audio Unit. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));
}

- (void)stop {
  OSStatus result = AudioOutputUnitStop(_ioUnit);
  NSCAssert2(
             result == noErr,
             @"Could not stop Audio Unit. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  NSError *error = nil;
  if (![[AVAudioSession sharedInstance] setActive:NO error:NULL]) {
    NSLog(@"Couldn't deactivate audio session: %@", error);
  }
}

- (void)initLinkData:(Float64)bpm {
  mach_timebase_info_data_t timeInfo;
  mach_timebase_info(&timeInfo);

  lock = OS_SPINLOCK_INIT;
  _linkData.ablLink = ABLLinkNew(bpm);
  _linkData.sampleRate = [[AVAudioSession sharedInstance] sampleRate];
  _linkData.secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
  _linkData.sharedEngineData.outputLatency =
  _linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency;
  _linkData.sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
  _linkData.sharedEngineData.proposeBpm = INVALID_BPM;
  _linkData.sharedEngineData.requestStart = NO;
  _linkData.sharedEngineData.requestStop = NO;
  _linkData.sharedEngineData.quantum = 4; // quantize to 4 beats
  _linkData.localEngineData = _linkData.sharedEngineData;
  _linkData.timeAtLastClick = 0;

  ABLLinkSetSessionTempoCallback(_linkData.ablLink, onSessionTempoChanged, (__bridge void *)self);
  ABLLinkSetStartStopCallback(_linkData.ablLink, onStartStopStateChanged, (__bridge void *)self);
}

- (void)setupAudioEngine {
  // Start a playback audio session
  NSError *sessionError = NULL;
  BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                  withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                                        error:&sessionError];
  if(!success) {
    NSLog(@"Error setting category Audio Session: %@", [sessionError localizedDescription]);
  }

  // Create Audio Unit
  AudioComponentDescription cd = {
    .componentManufacturer = kAudioUnitManufacturer_Apple,
    .componentType = kAudioUnitType_Output,
    .componentSubType = kAudioUnitSubType_RemoteIO,
    .componentFlags = 0,
    .componentFlagsMask = 0
  };

  AudioComponent component = AudioComponentFindNext(NULL, &cd);
  OSStatus result = AudioComponentInstanceNew(component, &_ioUnit);
  NSCAssert2(
             result == noErr,
             @"AudioComponentInstanceNew failed. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  AudioStreamBasicDescription asbd = {
    .mFormatID          = kAudioFormatLinearPCM,
    .mFormatFlags       =
    kAudioFormatFlagIsSignedInteger |
    kAudioFormatFlagIsPacked |
    kAudioFormatFlagsNativeEndian |
    kAudioFormatFlagIsNonInterleaved,
    .mChannelsPerFrame  = 2,
    .mBytesPerPacket    = sizeof(SInt16),
    .mFramesPerPacket   = 1,
    .mBytesPerFrame     = sizeof(SInt16),
    .mBitsPerChannel    = 8 * sizeof(SInt16),
    .mSampleRate        = _linkData.sampleRate
  };

  result = AudioUnitSetProperty(
                                _ioUnit,
                                kAudioUnitProperty_StreamFormat,
                                kAudioUnitScope_Input,
                                0,
                                &asbd,
                                sizeof(asbd));
  NSCAssert2(
             result == noErr,
             @"Set Stream Format failed. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  result = AudioUnitAddPropertyListener(
                                        _ioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        StreamFormatCallback,
                                        (__bridge void * _Nullable)(self));
  NSCAssert2(
             result == noErr,
             @"Adding Listener to Stream Format changes failed. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  _renderCallbackData = AudioEngineRenderCallbackData();
  _renderCallbackData.linkRef = &_linkData;
  _renderCallbackData.callback = self.renderCallbackBlock;

  // Set Audio Callback
  AURenderCallbackStruct ioRemoteInput;
  ioRemoteInput.inputProc = audioCallback;
  ioRemoteInput.inputProcRefCon = &_renderCallbackData;

  result = AudioUnitSetProperty(
                                _ioUnit,
                                kAudioUnitProperty_SetRenderCallback,
                                kAudioUnitScope_Input,
                                0,
                                &ioRemoteInput,
                                sizeof(ioRemoteInput));
  NSCAssert2(
             result == noErr,
             @"Could not set Render Callback. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  // Initialize Audio Unit
  result = AudioUnitInitialize(_ioUnit);
  NSCAssert2(
             result == noErr,
             @"Initializing Audio Unit failed. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));

  // Initilize Audiobus
  __weak typeof(self) weakSelf = self;
  dispatch_once(&audiobusInitOnceToken, ^{
    [weakSelf setupAudiobus:cd];
  });
}

- (void)deallocAudioEngine {
  // Uninitialize Audio Unit
  OSStatus result = AudioUnitUninitialize(_ioUnit);
  NSCAssert2(
             result == noErr,
             @"Uninitializing Audio Unit failed. Error code: %d '%.4s'",
             (int)result,
             (const char *)(&result));
}

- (void)setupAudiobus:(AudioComponentDescription)audescription {
  self.audiobusController = [[ABAudiobusController alloc] initWithApiKey:AUDIOBUS_API_KEY];

  AudioComponentDescription cd = {
    .componentManufacturer = FourCharCode('ccem'),
    .componentType = FourCharCode('auri'),
    .componentSubType = FourCharCode('arpg'),
    .componentFlags = 0,
    .componentFlagsMask = 0
  };

  ABAudioSenderPort *sender = [[ABAudioSenderPort alloc]
                               initWithName:@"ArpBud: Audiobus Port"
                               title:@"ArpBud: Audiobus Port"
                               audioComponentDescription:cd
                               audioUnit:_ioUnit];
  [sender setIsHidden:YES];

  self.midiSenderPort = [[ABMIDISenderPort alloc]
                         initWithName:@"ArpBud MIDI Out"
                         title:@"ArpBud MIDI Out"];

  __weak typeof(self) weakSelf = self;

  ABMIDIReceiverPort *midiReceiver = [[ABMIDIReceiverPort alloc]
                                      initWithName:@"ArpBud MIDI In"
                                      title:@"ArpBud MIDI In"
                                      receiverBlock:^(ABPort *__unsafe_unretained  _Nonnull source, const MIDIPacketList * _Nonnull packetList) {
                                        if (weakSelf.midiReceiverBlock) {
                                          weakSelf.midiReceiverBlock(source, packetList);
                                        }
                                      }];

  [self.audiobusController setEnableSendingCoreMIDIBlock:^(BOOL sendingEnabled) {
    if (weakSelf.coreMIDISendingEnabledBlock) {
      weakSelf.coreMIDISendingEnabledBlock(sendingEnabled);
    }
  }];

  [self.audiobusController setEnableReceivingCoreMIDIBlock:^(BOOL receivingEnabled) {
    if (weakSelf.coreMIDIReceivingEnabledBlock) {
      weakSelf.coreMIDIReceivingEnabledBlock(receivingEnabled);
    }
  }];

  [self.audiobusController addAudioSenderPort:sender];
  [self.audiobusController addMIDISenderPort:self.midiSenderPort];
  [self.audiobusController addMIDIReceiverPort:midiReceiver];
}

@end


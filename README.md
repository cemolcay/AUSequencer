AUSequencer
====

An example project/playground for a custom Audio Unit MIDI Sequencer that you can edit the steps (inluding the step count and the MIDI events (note, pitch, cc) of each step) and work with both Audiobus MIDI and AKMIDI in Ableton Link sync. Also, a future base for MIDI sequencer AUv3 plugin.
  
Main idea is creating an AudioUnit within an `AKNode` and initilize `Audiobus` audio sender port with that audio unit. Also, we are going to need a pair of Audiobus MIDI sender and receiver ports as well.
  
In the render loop of the AU, we are going to calculate the beat by Ableton Link time calculation utils.
  
When we advance the next beat, we are going to pull the step data from sequencer (which we can edit while sequencer is playing) and send the MIDI data of the step with either CoreMIDI (AKMIDI) or Audiobus MIDI according to Audiobus' `coreMIDISendingEnabled` property which returns true when user sets up an Audiobus session with our app.

In that way, we could bring the AudioKit, Audiobus, Ableton Link and AUv3 concepts toghether and hopefully create a MIDI Sequencer more useful than `AudioToolbox`'es `MusicPlayer`/`MusicSequencer`/`MusicTrack` API's.

You are going to need AudioKit and Audiobus pods with a `pod install` as well as `LinkKit` of Ableton Link, which you are going to add manually due to the privacy of the SDK.

In this example, I'm going to implement an arpeggiator which works by either MIDI keyboard commands or sequencing the MIDI notes which basicly automating the MIDI Keyboard commands.
  
Arpeggiator will be halfstep based. If it has 4 steps with values (0, +2, -1, +4), if you press C4 on MIDI keyboard than it will produce (C4 + 0 = C4, C4 + 2 = D4, C4 - 1 = B3 and C4 + 4 = E4). If you put two steps to the sequencer with C4 and D4 than it will produce (1st step = C4, D4, B3, E4, 2nd step = D4, E4, C#4, F#4).
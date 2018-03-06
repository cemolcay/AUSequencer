//
//  MIDIManager.swift
//  ArpBud
//
//  Created by Cem Olcay on 16.02.2018.
//  Copyright © 2018 cemolcay. All rights reserved.
//

import UIKit
import AudioKit

class MIDIManager: AKMIDIListener {
  static let shared = MIDIManager()
  var midi = AKMIDI()
  var midiChannel = MIDIChannel(0)

  var isVirtualOutputEnabled = true
  var coreMIDISendingEnabled = true
  var coreMIDIReceivingEnabled = true

  init() {
    midi.addListener(self)
    midi.openInput()
  }

  // MARK: Endpoints

  func openVirtualOut() {
    midi.createVirtualOutputPort(name: "ArpBud Virtual Out")
    isVirtualOutputEnabled = true
  }

  func closeVirtualOutput() {
    midi.destroyVirtualPorts()
    isVirtualOutputEnabled = false
  }

  func midiOutputIsEnabled(name: String) -> Bool {
    return midi.destinationInfos.contains(where: { $0.displayName == name })
  }

  func midiInputIsEnabled(name: String) -> Bool {
    return midi.endpoints.contains(where: { $0.key == name })
  }

  // MARK: Audiobus MIDI

  func midiDidReceive(port: ABPort, packetList: UnsafePointer<MIDIPacketList>) {
    let packet = AKMIDIEvent(packet: packetList.pointee.packet)
    print(packet)
  }

  // MARK: AKMIDIListener

  func receivedMIDINoteOn(noteNumber: MIDINoteNumber, velocity: MIDIVelocity, channel: MIDIChannel) {
    guard coreMIDIReceivingEnabled else { return }
    print("note on \(noteNumber)")
  }

  func receivedMIDINoteOff(noteNumber: MIDINoteNumber, velocity: MIDIVelocity, channel: MIDIChannel) {
    guard coreMIDIReceivingEnabled else { return }
    print("note off \(noteNumber)")
  }
}

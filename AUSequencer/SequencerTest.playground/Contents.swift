//: Playground - noun: a place where people can play

import UIKit

indirect enum StepSequencerArpeggio {
  case up
  case down
  case updown(StepSequencerArpeggio)
  case random
}

class StepSequencer {
  private(set) var currentStepIndex = 0
  var arpeggio = StepSequencerArpeggio.up
  var count = 0

  var nextStepIndex: Int {
    // Check if we have steps and we are in bounds.
    guard count > 0, currentStepIndex >= 0, currentStepIndex < count else {
      currentStepIndex = 0
      return currentStepIndex
    }

    // Hold a reference of current step index for returning.
    let current = currentStepIndex

    // Calculate next step index.
    switch arpeggio {
    case .up:
      if currentStepIndex + 1 >= count {
        currentStepIndex = 0
      } else {
        currentStepIndex += 1
      }
    case .down:
      if currentStepIndex - 1 < 0 {
        currentStepIndex = count - 1
      } else {
        currentStepIndex -= 1
      }
    case .updown(let state):
      switch state {
      case .up:
        if currentStepIndex + 1 >= count {
          currentStepIndex = count - 1
          arpeggio = .updown(.down)
        } else {
          currentStepIndex += 1
        }
      case .down:
        if currentStepIndex - 1 < 0 {
          currentStepIndex = 0
          arpeggio = .updown(.up)
        } else {
          currentStepIndex -= 1
        }
      default:
        currentStepIndex = 0
      }
    case .random:
      currentStepIndex = Int(arc4random_uniform(UInt32(count)))
    }

    return current
  }
}

var seq = StepSequencer()
seq.count = 10
seq.arpeggio = .updown(.up)

for i in 0..<130 {
  seq.nextStepIndex
}

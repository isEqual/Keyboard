import SwiftUI
import Tonic

/// This handles the interaction for key, so the user can provide their own
/// visual representation.
public struct KeyboardKeyContainer: View {

    var pitch: Pitch
    @ObservedObject var model: KeyboardModel

    var settings: KeyboardSettings
    var noteOn: (Pitch) -> Void
    var noteOff: (Pitch) -> Void

    func findPitch(location: CGPoint) -> Pitch? {
        var matches: [Pitch] = []
        for rect in model.keyRects {
            if rect.value.contains(location) {
                matches.append(rect.key)
            }
        }
        if matches.count == 1 { return matches.first! }
        if matches.count > 1 {
            for match in matches {
                if match.note(in: .C).accidental != .natural {
                    return match
                }
            }
        }
        return nil
    }

    func sendEvents(old: [CGPoint: Pitch]) {
        let oldSet = PitchSet(old.values)
        let newSet = PitchSet(model.touchedPitches.values)

        let newPitches = newSet.subtracting(oldSet)
        let removedPitches = oldSet.subtracting(newSet)

        for pitch in removedPitches.array {
            noteOff(pitch)
        }

        for pitch in newPitches.array {
            noteOn(pitch)
        }
    }

    func rect(rect: CGRect) -> some View {
        var modRect = rect
        if pitch.note(in: .C).accidental != .natural {
            modRect = rect.offsetBy(dx: rect.width / 2, dy: 0)
        }
        model.keyRects[pitch] = modRect
        
        return KeyboardKey(pitch: pitch, model: model)
        .offset(x: pitch.note(in: .C).accidental == .natural ? 0 : rect.width / 2)

        .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { gesture in
                guard !settings.latching else { return }
                if let pitch = findPitch(location: gesture.location) {
                    let old = model.touchedPitches
                    model.touchedPitches[gesture.startLocation] = pitch
                    sendEvents(old: old)
                }
            }
            .onEnded { gesture in
                guard !settings.latching else { return }
                let old = model.touchedPitches
                model.touchedPitches.removeValue(forKey: gesture.startLocation)
                sendEvents(old: old)
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded({ _ in
                guard settings.latching else { return }
                if model.touchedPitches.values.contains(pitch) {
                    let old = model.touchedPitches
                    for item in model.touchedPitches {
                        if item.value == pitch {
                            model.touchedPitches.removeValue(forKey: item.key)
                        }
                    }
                    sendEvents(old: old)
                } else {
                    let old = model.touchedPitches
                    model.touchedPitches[CGPoint(x: rect.midX + CGFloat(pitch.intValue)/100.0, y: rect.midY)] = pitch
                    sendEvents(old: old)
                }
            })
        )
    }

    public var body: some View {
        GeometryReader { proxy in
            rect(rect: proxy.frame(in: .global))
        }
    }
}
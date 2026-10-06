import AVFoundation
import Foundation

final class Equalizer {
    let eq: AVAudioUnitEQ
    private(set) var frequencies: [Float]

    static let bands10: [Float] = [32, 64, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]
    static let bands8: [Float] = [63, 125, 250, 500, 1_000, 2_000, 4_000, 8_000]
    static let bands16: [Float] = [
        25, 40, 63, 100, 160, 250, 400, 630,
        1_000, 1_600, 2_500, 4_000, 6_300, 10_000, 12_500, 16_000,
    ]

    var globalGain: Float {
        get { eq.globalGain }
        set { eq.globalGain = newValue }
    }

    var enabled: Bool {
        get { !eq.bypass }
        set { eq.bypass = !newValue }
    }

    init(frequencies: [Float] = Equalizer.bands10) {
        eq = AVAudioUnitEQ(numberOfBands: Equalizer.bands16.count)
        self.frequencies = []
        apply(frequencies)
    }

    func apply(_ frequencies: [Float]) {
        let active = Array(frequencies.prefix(eq.bands.count))
        self.frequencies = active
        let bandwidth = Self.graphicBandwidth(bandCount: active.count)
        for (i, band) in eq.bands.enumerated() {
            if i < active.count {
                band.filterType = .parametric
                band.frequency = active[i]
                band.bandwidth = bandwidth
                band.gain = 0
                band.bypass = false
            } else {
                band.gain = 0
                band.bypass = true
            }
        }
        eq.globalGain = 0
    }

    func gain(at index: Int) -> Float {
        guard frequencies.indices.contains(index) else { return 0 }
        return eq.bands[index].gain
    }

    func setGain(_ gain: Float, at index: Int) {
        guard frequencies.indices.contains(index) else { return }
        eq.bands[index].gain = max(-24, min(24, gain))
    }

    func setGains(_ gains: [Float]) {
        for (i, g) in gains.enumerated() where i < frequencies.count {
            setGain(g, at: i)
        }
    }

    func flat() {
        for index in frequencies.indices {
            eq.bands[index].gain = 0
        }
        eq.globalGain = 0
    }

    static func label(for hz: Float) -> String {
        if hz >= 1000 {
            let k = hz / 1000
            return k.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(k))k"
                : String(format: "%.1fk", k)
        }
        return "\(Int(hz))"
    }

    static func graphicBandwidth(bandCount: Int) -> Float {
        bandCount > 10 ? 0.67 : 1
    }
}

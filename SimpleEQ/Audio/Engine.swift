import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation

@MainActor
final class Engine: ObservableObject {
    enum State: Equatable {
        case stopped
        case running
        case error(String)
    }

    enum BandCount: String, CaseIterable, Identifiable {
        case eight = "8"
        case ten = "10"
        case sixteen = "16"

        var id: String { rawValue }

        var frequencies: [Float] {
            switch self {
            case .eight: return Equalizer.bands8
            case .ten: return Equalizer.bands10
            case .sixteen: return Equalizer.bands16
            }
        }
    }

    @Published private(set) var state: State = .stopped
    @Published private(set) var statusMessage: String = "Stopped"

    private var captureEngine: AVAudioEngine?
    private var playback: PlaybackUnit?
    private(set) var equalizer: Equalizer
    private let ring = CircularBuffer(capacityFrames: 16384, primeFrames: 2048)
    private var tapInstalled = false
    private var previousOutputUID: String?
    private var sharedRate: Double = 48_000

    private static let claimActiveKey = "simpleEQ.outputClaimActive"
    private static let claimOutputUIDKey = "simpleEQ.previousOutputUID"

    init() {
        equalizer = Equalizer(frequencies: BandCount.ten.frequencies)
    }

    static func recoverClaimedOutput() -> String? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: claimActiveKey) else { return nil }
        let savedUID = defaults.string(forKey: claimOutputUIDKey)
        let current = AudioDevices.defaultOutputID().flatMap { AudioDevices.info(id: $0) }

        if let savedUID, current?.uid == savedUID {
            clearClaim()
            return nil
        }

        if let savedUID,
           let device = AudioDevices.list().first(where: { $0.uid == savedUID && $0.hasOutput }) {
            do {
                try AudioDevices.setDefaultOutput(device.id)
                clearClaim()
                return nil
            } catch {
                return "Could not restore the previous system output. It may still be the loopback."
            }
        }

        if current?.isSystemLoopback == true,
           let fallback = AudioDevices.outputs().first(where: { !$0.isSystemLoopback }) {
            do {
                try AudioDevices.setDefaultOutput(fallback.id)
                clearClaim()
                return nil
            } catch {
                return "Could not move system output off the loopback."
            }
        }

        clearClaim()
        return nil
    }

    func start(inputID: AudioDeviceID, outputID: AudioDeviceID, claimSystemOutput: Bool = true) throws {
        _ = hardStop()

        do {
            if claimSystemOutput {
                try claimSystemOutputDevice(loopbackID: inputID)
            }
            try buildCapture(loopbackID: inputID)
            try buildPlayback(speakersID: outputID)
        } catch {
            _ = hardStop()
            throw error
        }

        state = .running
        statusMessage = "Running · \(Int(sharedRate)) Hz"
    }

    func stop() {
        if let failure = hardStop() {
            state = .error(failure)
            statusMessage = failure
        } else {
            state = .stopped
            statusMessage = "Stopped"
        }
    }

    private func claimSystemOutputDevice(loopbackID: AudioDeviceID) throws {
        if previousOutputUID == nil {
            if let saved = UserDefaults.standard.string(forKey: Self.claimOutputUIDKey) {
                previousOutputUID = saved
            } else if let current = AudioDevices.defaultOutputID().flatMap({ AudioDevices.info(id: $0) }),
                      !current.isSystemLoopback {
                previousOutputUID = current.uid
            } else if let fallback = AudioDevices.outputs().first(where: { !$0.isSystemLoopback }) {
                previousOutputUID = fallback.uid
            }
            if let uid = previousOutputUID {
                UserDefaults.standard.set(uid, forKey: Self.claimOutputUIDKey)
                UserDefaults.standard.set(true, forKey: Self.claimActiveKey)
            }
        }
        try AudioDevices.setDefaultOutput(loopbackID)
    }

    private func buildCapture(loopbackID: AudioDeviceID) throws {
        ring.reset()

        let capture = AVAudioEngine()
        captureEngine = capture

        let input = capture.inputNode
        guard let audioUnit = input.audioUnit else { throw EngineError.badFormat }
        var device = loopbackID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw EngineError.startFailed("Could not open the input device (\(AudioDevices.statusString(status))).")
        }

        let format = input.inputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw EngineError.badFormat
        }
        sharedRate = format.sampleRate

        capture.attach(equalizer.eq)
        capture.connect(capture.inputNode, to: equalizer.eq, format: format)
        capture.connect(equalizer.eq, to: capture.mainMixerNode, format: format)
        capture.mainMixerNode.outputVolume = 0

        let channels = Int(format.channelCount)
        equalizer.eq.installTap(onBus: 0, bufferSize: 512, format: format) { [ring] buffer, _ in
            guard let data = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let left = UnsafePointer(data[0])
            let right = channels > 1 ? UnsafePointer(data[1]) : left
            ring.write(left: left, right: right, frameCount: frames)
        }
        tapInstalled = true

        capture.prepare()
        try capture.start()
    }

    private func buildPlayback(speakersID: AudioDeviceID) throws {
        let unit = PlaybackUnit(ring: ring)
        try unit.start(deviceID: speakersID, sampleRate: sharedRate)
        playback = unit
    }

    @discardableResult
    private func hardStop() -> String? {
        if tapInstalled {
            equalizer.eq.removeTap(onBus: 0)
            tapInstalled = false
        }
        if let capture = captureEngine {
            if capture.isRunning { capture.stop() }
            if capture.attachedNodes.contains(equalizer.eq) {
                capture.disconnectNodeOutput(equalizer.eq)
                capture.disconnectNodeInput(equalizer.eq)
                capture.detach(equalizer.eq)
            }
            capture.reset()
        }
        captureEngine = nil
        playback?.stop()
        playback = nil
        ring.reset()
        return restoreSavedOutput()
    }

    private func restoreSavedOutput() -> String? {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.claimActiveKey) || previousOutputUID != nil else { return nil }
        let uid = previousOutputUID ?? defaults.string(forKey: Self.claimOutputUIDKey)
        guard let uid else {
            Self.clearClaim()
            return nil
        }
        guard let device = AudioDevices.list().first(where: { $0.uid == uid && $0.hasOutput }) else {
            return "Could not restore the previous system output."
        }
        do {
            try AudioDevices.setDefaultOutput(device.id)
        } catch {
            return error.localizedDescription
        }
        previousOutputUID = nil
        Self.clearClaim()
        return nil
    }

    private static func clearClaim() {
        UserDefaults.standard.set(false, forKey: claimActiveKey)
        UserDefaults.standard.removeObject(forKey: claimOutputUIDKey)
    }
}

enum EngineError: LocalizedError {
    case badFormat
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .badFormat:
            return "The loopback input has no usable format. Check that the device is connected."
        case .startFailed(let message):
            return message
        }
    }
}

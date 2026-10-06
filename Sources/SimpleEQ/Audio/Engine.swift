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

    private(set) var equalizer: Equalizer
    private var audioEngine: AVAudioEngine?
    private var configObserver: NSObjectProtocol?
    private var aggregateID: AudioDeviceID = 0
    private var previousOutputUID: String?
    private var routeInputUID: String?
    private var routeOutputUID: String?
    private var aliveBlock: AudioObjectPropertyListenerBlock?
    private var watchedDevices: [AudioDeviceID] = []
    private var watchingDeviceList = false
    private var handlingLoss = false
    private var sharedRate: Double = 48_000

    private static let claimActiveKey = "simpleEQ.outputClaimActive"
    private static let claimOutputUIDKey = "simpleEQ.previousOutputUID"
    private static let aggregateUID = "app.simpleeq.aggregate"

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

        guard let loopback = AudioDevices.info(id: inputID), loopback.inputChannels > 0 else {
            throw EngineError.badFormat
        }
        guard let speakers = AudioDevices.info(id: outputID), speakers.outputChannels > 0 else {
            throw EngineError.startFailed("The output device has no channels.")
        }

        routeInputUID = loopback.uid
        routeOutputUID = speakers.uid

        do {
            if claimSystemOutput {
                try claimSystemOutputDevice(loopbackID: loopback.id)
            }
            aggregateID = try createAggregate(loopback: loopback, speakers: speakers)
            try buildEngine(on: aggregateID)
            startWatching(loopback: loopback.id, speakers: speakers.id)
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

    private func createAggregate(loopback: AudioDeviceInfo, speakers: AudioDeviceInfo) throws -> AudioDeviceID {
        let description: NSDictionary = [
            kAudioAggregateDeviceNameKey: "SimpleEQ",
            kAudioAggregateDeviceUIDKey: Self.aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: NSNumber(value: 1),
            kAudioAggregateDeviceIsStackedKey: NSNumber(value: 0),
            kAudioAggregateDeviceMainSubDeviceKey: speakers.uid,
            kAudioAggregateDeviceSubDeviceListKey: [
                [
                    kAudioSubDeviceUIDKey: speakers.uid,
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: 0),
                    kAudioSubDeviceInputChannelsKey: NSNumber(value: 0),
                    kAudioSubDeviceOutputChannelsKey: NSNumber(value: speakers.outputChannels),
                ],
                [
                    kAudioSubDeviceUIDKey: loopback.uid,
                    kAudioSubDeviceDriftCompensationKey: NSNumber(value: 1),
                    kAudioSubDeviceDriftCompensationQualityKey: NSNumber(value: kAudioAggregateDriftCompensationMediumQuality),
                    kAudioSubDeviceInputChannelsKey: NSNumber(value: loopback.inputChannels),
                    kAudioSubDeviceOutputChannelsKey: NSNumber(value: 0),
                ],
            ],
        ]
        var aggregate = AudioObjectID(0)
        let status = AudioHardwareCreateAggregateDevice(description, &aggregate)
        guard status == noErr, aggregate != 0 else {
            throw EngineError.startFailed("Could not build the audio route (\(AudioDevices.statusString(status))).")
        }
        return aggregate
    }

    private func buildEngine(on device: AudioDeviceID) throws {
        let engine = AVAudioEngine()
        audioEngine = engine
        // Input and output nodes share one audio unit on macOS. Setting the device
        // through both nodes leaves the engine "running" with no I/O, so set it once.
        try setDevice(device, on: engine.outputNode)

        // AVAudioEngine keeps reporting the default input's format after the device
        // changes, so read the aggregate's format from the audio unit itself.
        let format = try deviceInputFormat(of: engine.inputNode)
        sharedRate = format.sampleRate

        engine.attach(equalizer.eq)
        engine.connect(engine.inputNode, to: equalizer.eq, format: format)
        engine.connect(equalizer.eq, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()

        // Claiming the system output makes macOS send a configuration change, and
        // AVAudioEngine answers it by moving its I/O to the default device, which is
        // now the loopback. Point the same engine back at the aggregate when that
        // happens; building a new engine instead gets moved again, in a loop.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleConfigurationChange() }
        }
    }

    private func handleConfigurationChange() {
        guard state == .running, let engine = audioEngine, aggregateID != 0 else { return }
        if engine.isRunning, currentDevice(of: engine) == aggregateID { return }
        engine.stop()
        do {
            try setDevice(aggregateID, on: engine.outputNode)
            try engine.start()
        } catch {
            let failure = hardStop()
            let message = failure ?? error.localizedDescription
            state = .error(message)
            statusMessage = message
        }
    }

    private func currentDevice(of engine: AVAudioEngine) -> AudioDeviceID? {
        guard let audioUnit = engine.outputNode.audioUnit else { return nil }
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioUnitGetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            &size
        )
        return status == noErr ? device : nil
    }

    private func tearDownEngine() {
        if let observer = configObserver {
            NotificationCenter.default.removeObserver(observer)
            configObserver = nil
        }
        if let engine = audioEngine {
            if engine.isRunning { engine.stop() }
            if engine.attachedNodes.contains(equalizer.eq) {
                engine.disconnectNodeOutput(equalizer.eq)
                engine.disconnectNodeInput(equalizer.eq)
                engine.detach(equalizer.eq)
            }
            engine.reset()
        }
        audioEngine = nil
    }

    private func deviceInputFormat(of node: AVAudioInputNode) throws -> AVAudioFormat {
        guard let audioUnit = node.audioUnit else { throw EngineError.badFormat }
        var description = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioUnitGetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            1,
            &description,
            &size
        )
        guard status == noErr,
              description.mSampleRate > 0,
              description.mChannelsPerFrame > 0,
              let format = AVAudioFormat(
                  standardFormatWithSampleRate: description.mSampleRate,
                  channels: description.mChannelsPerFrame
              ) else {
            throw EngineError.badFormat
        }
        return format
    }

    private func setDevice(_ id: AudioDeviceID, on node: AVAudioIONode) throws {
        guard let audioUnit = node.audioUnit else { throw EngineError.badFormat }
        var device = id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &device,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else {
            throw EngineError.startFailed("Could not open the audio route (\(AudioDevices.statusString(status))).")
        }
    }

    private func startWatching(loopback: AudioDeviceID, speakers: AudioDeviceID) {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                self?.handleDeviceLoss()
            }
        }
        aliveBlock = block

        var alive = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for id in [loopback, speakers] {
            if AudioObjectAddPropertyListenerBlock(id, &alive, .main, block) == noErr {
                watchedDevices.append(id)
            }
        }

        var devices = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devices, .main, block) == noErr {
            watchingDeviceList = true
        }
    }

    private func stopWatching() {
        guard let block = aliveBlock else { return }
        var alive = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        for id in watchedDevices {
            AudioObjectRemovePropertyListenerBlock(id, &alive, .main, block)
        }
        watchedDevices.removeAll()

        if watchingDeviceList {
            var devices = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devices, .main, block)
            watchingDeviceList = false
        }
        aliveBlock = nil
    }

    private func handleDeviceLoss() {
        guard state == .running, !handlingLoss else { return }
        guard routeMissing() else { return }
        handlingLoss = true
        defer { handlingLoss = false }
        let failure = hardStop()
        let message = failure ?? "An audio device disconnected. System output was restored."
        state = .error(message)
        statusMessage = message
    }

    private func routeMissing() -> Bool {
        let devices = AudioDevices.list()
        guard let inputUID = routeInputUID, let outputUID = routeOutputUID else { return true }
        guard let input = devices.first(where: { $0.uid == inputUID }),
              let output = devices.first(where: { $0.uid == outputUID }) else { return true }
        return !isAlive(input.id) || !isAlive(output.id)
    }

    private func isAlive(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsAlive,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var alive: UInt32 = 1
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &alive) == noErr else { return false }
        return alive != 0
    }

    @discardableResult
    private func hardStop() -> String? {
        stopWatching()
        tearDownEngine()
        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        routeInputUID = nil
        routeOutputUID = nil
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

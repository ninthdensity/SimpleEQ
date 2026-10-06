import AVFoundation
import Combine
import CoreAudio
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var inputs: [AudioDeviceInfo] = []
    @Published var outputs: [AudioDeviceInfo] = []

    @Published var selectedInputID: AudioDeviceID?
    @Published var selectedOutputID: AudioDeviceID?

    @Published var bandCount: Engine.BandCount = .ten
    @Published var gains: [Float] = Array(repeating: 0, count: 10)
    @Published var globalGain: Float = 0
    @Published var eqEnabled: Bool = true
    @Published var claimSystemOutput: Bool = true

    @Published var errorMessage: String?

    let engine = Engine()

    private var cancellables = Set<AnyCancellable>()
    private var startGeneration = 0

    var frequencies: [Float] { engine.equalizer.frequencies }

    init() {
        if let recovery = Engine.recoverClaimedOutput() {
            errorMessage = recovery
        }
        refreshDevices()
        autoPickDevices()
        syncGainsFromEngine()

        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        engine.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                if case .error(let message) = state {
                    self.errorMessage = message
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stop()
            }
        }
    }

    func refreshDevices() {
        inputs = AudioDevices.inputs()
        outputs = AudioDevices.outputs()
        if let id = selectedInputID, !inputs.contains(where: { $0.id == id }) {
            selectedInputID = nil
        }
        if let id = selectedOutputID, !outputs.contains(where: { $0.id == id }) {
            selectedOutputID = nil
        }
    }

    func autoPickDevices() {
        if let loop = AudioDevices.preferredLoopback() {
            selectedInputID = loop.id
        } else {
            selectedInputID = nil
        }

        if let def = AudioDevices.defaultOutputID(),
           let info = outputs.first(where: { $0.id == def }),
           !info.isSystemLoopback {
            selectedOutputID = def
        } else {
            selectedOutputID = outputs.first(where: { !$0.isSystemLoopback })?.id ?? outputs.first?.id
        }
    }

    func applyBandCount(_ count: Engine.BandCount) {
        bandCount = count
        engine.equalizer.apply(count.frequencies)
        gains = Array(repeating: 0, count: count.frequencies.count)
        globalGain = 0
        pushEQ()
    }

    func setGain(_ value: Float, at index: Int) {
        guard gains.indices.contains(index) else { return }
        gains[index] = value
        engine.equalizer.setGain(value, at: index)
    }

    func setGlobalGain(_ value: Float) {
        globalGain = value
        engine.equalizer.globalGain = value
    }

    func setEnabled(_ on: Bool) {
        eqEnabled = on
        engine.equalizer.enabled = on
    }

    func flat() {
        gains = Array(repeating: 0, count: frequencies.count)
        globalGain = 0
        engine.equalizer.flat()
    }

    func toggleRunning() {
        if engine.state == .running {
            stop()
            return
        }
        start()
    }

    func start() {
        startGeneration += 1
        let generation = startGeneration
        errorMessage = nil
        refreshDevices()

        guard let inID = selectedInputID, AudioDevices.info(id: inID) != nil else {
            selectedInputID = nil
            errorMessage = "Pick an input. For system-wide EQ, install BlackHole 2ch with brew install blackhole-2ch."
            return
        }
        guard let outID = selectedOutputID, AudioDevices.info(id: outID) != nil else {
            selectedOutputID = nil
            errorMessage = "Pick an output device."
            return
        }
        guard inID != outID else {
            errorMessage = "Input and output must be different devices."
            return
        }

        if claimSystemOutput {
            guard let info = AudioDevices.info(id: inID) else { return }
            if !info.hasOutput {
                errorMessage = "“\(info.name)” is input-only, so macOS cannot make it the system output. Use BlackHole 2ch, or turn off Claim system output."
                return
            }
            if !info.isSystemLoopback {
                errorMessage = "“\(info.name)” is not a loopback device. Claim system output needs a loopback such as BlackHole 2ch. Turn the switch off if you route audio yourself."
                return
            }
        }

        requestMicPermission { [weak self] granted in
            Task { @MainActor in
                guard let self else { return }
                guard generation == self.startGeneration else { return }
                guard granted else {
                    self.errorMessage = "Microphone access is off. Turn on SimpleEQ in System Settings, Privacy & Security, Microphone. The app reads the loopback device. It does not use your microphone."
                    return
                }
                do {
                    try self.engine.start(inputID: inID, outputID: outID, claimSystemOutput: self.claimSystemOutput)
                    self.pushEQ()
                } catch {
                    self.errorMessage = error.localizedDescription
                    if self.engine.state == .running { self.stop() }
                }
            }
        }
    }

    private func requestMicPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { completion($0) }
        } else {
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                completion(true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { completion($0) }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }

    func stop() {
        startGeneration += 1
        engine.stop()
        if case .error(let message) = engine.state {
            errorMessage = message
        }
    }

    private func pushEQ() {
        engine.equalizer.setGains(gains)
        engine.equalizer.globalGain = globalGain
        engine.equalizer.enabled = eqEnabled
    }

    private func syncGainsFromEngine() {
        gains = frequencies.indices.map { engine.equalizer.gain(at: $0) }
        globalGain = engine.equalizer.globalGain
        eqEnabled = engine.equalizer.enabled
    }
}

import CoreAudio
import Foundation

struct AudioDeviceInfo: Identifiable, Hashable, Sendable {
    let id: AudioDeviceID
    let name: String
    let uid: String
    let hasInput: Bool
    let hasOutput: Bool

    var isSystemLoopback: Bool {
        let hay = (name + " " + uid).lowercased()
        if Self.loopbackDenylist.contains(where: { hay.contains($0) }) { return false }
        return Self.loopbackAllowlist.contains { hay.contains($0) }
    }

    private static let loopbackDenylist = ["zoom", "teams", "webex", "skype", "parrot", "discord"]
    private static let loopbackAllowlist = ["blackhole", "eqmac", "soundflower", "loopback", "background music"]
}

enum AudioDeviceError: LocalizedError {
    case propertyFailed(String)

    var errorDescription: String? {
        switch self {
        case .propertyFailed(let message): return message
        }
    }
}

enum AudioDevices {
    static func list() -> [AudioDeviceInfo] {
        guard let ids = allDeviceIDs() else { return [] }
        return ids.compactMap { info(for: $0) }
    }

    static func inputs() -> [AudioDeviceInfo] {
        list().filter(\.hasInput)
    }

    static func outputs() -> [AudioDeviceInfo] {
        list().filter(\.hasOutput)
    }

    static func info(id: AudioDeviceID) -> AudioDeviceInfo? {
        info(for: id)
    }

    static func defaultOutputID() -> AudioDeviceID? {
        deviceID(for: kAudioHardwarePropertyDefaultOutputDevice)
    }

    static func setDefaultOutput(_ id: AudioDeviceID) throws {
        if let info = info(for: id), !info.hasOutput {
            throw AudioDeviceError.propertyFailed(
                "“\(info.name)” has no output, so macOS will not use it as the system output. Use BlackHole 2ch."
            )
        }
        try setDeviceID(id, for: kAudioHardwarePropertyDefaultOutputDevice)
        if defaultOutputID() != id {
            let name = info(for: id)?.name ?? "that device"
            throw AudioDeviceError.propertyFailed(
                "macOS refused to make “\(name)” the system output. Use BlackHole 2ch."
            )
        }
    }

    static func preferredLoopback() -> AudioDeviceInfo? {
        let devices = list()
        return devices.first(where: { $0.isSystemLoopback && $0.hasInput && $0.hasOutput })
            ?? devices.first(where: { $0.isSystemLoopback && $0.hasInput })
    }

    static func statusString(_ status: OSStatus) -> String {
        if status == noErr { return "noErr" }
        let u = UInt32(bitPattern: status)
        let bytes: [UInt8] = [
            UInt8((u >> 24) & 0xff),
            UInt8((u >> 16) & 0xff),
            UInt8((u >> 8) & 0xff),
            UInt8(u & 0xff),
        ]
        if bytes.allSatisfy({ isprint(Int32($0)) != 0 }) {
            return "'\(String(bytes: bytes, encoding: .macOSRoman) ?? "?")' (\(status))"
        }
        return "\(status)"
    }

    private static func allDeviceIDs() -> [AudioDeviceID]? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr,
              size > 0 else { return nil }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else {
            return nil
        }
        return ids
    }

    private static func info(for id: AudioDeviceID) -> AudioDeviceInfo? {
        guard let name = stringProperty(id, kAudioObjectPropertyName),
              let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) else { return nil }
        let inCh = channelCount(id, scope: kAudioObjectPropertyScopeInput)
        let outCh = channelCount(id, scope: kAudioObjectPropertyScopeOutput)
        return AudioDeviceInfo(id: id, name: name, uid: uid, hasInput: inCh > 0, hasOutput: outCh > 0)
    }

    private static func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr, size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr else { return 0 }

        let abl = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        let bufs = UnsafeMutableAudioBufferListPointer(abl)
        return bufs.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString?>.size)
        var cf: CFString?
        let status = withUnsafeMutablePointer(to: &cf) { ptr in
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, ptr)
        }
        guard status == noErr, let cf else { return nil }
        return cf as String
    }

    private static func deviceID(for selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id) == noErr,
              id != 0 else { return nil }
        return id
    }

    private static func setDeviceID(_ id: AudioDeviceID, for selector: AudioObjectPropertySelector) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = id
        let size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &value)
        guard status == noErr else {
            throw AudioDeviceError.propertyFailed(
                "Could not change the system output (\(statusString(status)))."
            )
        }
    }
}

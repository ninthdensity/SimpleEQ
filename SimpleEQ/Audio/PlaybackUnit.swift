import AudioToolbox
import CoreAudio
import Foundation

final class PlaybackUnit {
    private var unit: AudioUnit?
    private let ring: CircularBuffer
    private let scratchFrames = 4096
    private let scratchL: UnsafeMutablePointer<Float>
    private let scratchR: UnsafeMutablePointer<Float>

    init(ring: CircularBuffer) {
        self.ring = ring
        scratchL = .allocate(capacity: scratchFrames)
        scratchR = .allocate(capacity: scratchFrames)
    }

    deinit {
        stop()
        scratchL.deallocate()
        scratchR.deallocate()
    }

    func start(deviceID: AudioDeviceID, sampleRate: Double) throws {
        stop()

        var desc = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let comp = AudioComponentFindNext(nil, &desc) else {
            throw PlaybackError.noComponent
        }

        var au: AudioUnit?
        var status = AudioComponentInstanceNew(comp, &au)
        guard status == noErr, let au else { throw PlaybackError.osStatus("InstanceNew", status) }
        unit = au

        try setIO(au, enable: 1, scope: kAudioUnitScope_Output, bus: 0)
        try setIO(au, enable: 0, scope: kAudioUnitScope_Input, bus: 1)

        var dev = deviceID
        status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &dev,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw PlaybackError.osStatus("CurrentDevice", status) }

        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat
                | kAudioFormatFlagIsPacked
                | kAudioFormatFlagIsNonInterleaved,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        status = AudioUnitSetProperty(
            au,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Input,
            0,
            &format,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard status == noErr else { throw PlaybackError.osStatus("StreamFormat", status) }

        var callback = AURenderCallbackStruct(
            inputProc: playbackRenderCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        status = AudioUnitSetProperty(
            au,
            kAudioUnitProperty_SetRenderCallback,
            kAudioUnitScope_Input,
            0,
            &callback,
            UInt32(MemoryLayout<AURenderCallbackStruct>.size)
        )
        guard status == noErr else { throw PlaybackError.osStatus("SetRenderCallback", status) }

        status = AudioUnitInitialize(au)
        guard status == noErr else { throw PlaybackError.osStatus("Initialize", status) }

        status = AudioOutputUnitStart(au)
        guard status == noErr else { throw PlaybackError.osStatus("Start", status) }
    }

    func stop() {
        guard let au = unit else { return }
        AudioOutputUnitStop(au)
        AudioUnitUninitialize(au)
        AudioComponentInstanceDispose(au)
        unit = nil
    }

    fileprivate func render(frameCount: UInt32, abl: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        let frames = Int(frameCount)
        guard frames > 0, !buffers.isEmpty else { return noErr }

        if buffers.count >= 2,
           let left = buffers[0].mData?.assumingMemoryBound(to: Float.self),
           let right = buffers[1].mData?.assumingMemoryBound(to: Float.self) {
            ring.read(left: left, right: right, frameCount: frames)
            return noErr
        }

        guard let interleaved = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
        if frames > scratchFrames {
            memset(interleaved, 0, Int(buffers[0].mDataByteSize))
            return noErr
        }
        let channels = max(1, Int(buffers[0].mNumberChannels))
        ring.read(left: scratchL, right: scratchR, frameCount: frames)
        for i in 0..<frames {
            interleaved[i * channels] = scratchL[i]
            if channels > 1 { interleaved[i * channels + 1] = scratchR[i] }
        }
        return noErr
    }

    private func setIO(_ au: AudioUnit, enable: UInt32, scope: AudioUnitScope, bus: AudioUnitElement) throws {
        var flag = enable
        let status = AudioUnitSetProperty(
            au,
            kAudioOutputUnitProperty_EnableIO,
            scope,
            bus,
            &flag,
            UInt32(MemoryLayout<UInt32>.size)
        )
        guard status == noErr else { throw PlaybackError.osStatus("EnableIO", status) }
    }
}

private func playbackRenderCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    guard let ioData else { return noErr }
    let playback = Unmanaged<PlaybackUnit>.fromOpaque(inRefCon).takeUnretainedValue()
    return playback.render(frameCount: inNumberFrames, abl: ioData)
}

enum PlaybackError: LocalizedError {
    case noComponent
    case osStatus(String, OSStatus)

    var errorDescription: String? {
        switch self {
        case .noComponent:
            return "Could not find the output audio unit."
        case .osStatus(let step, let status):
            return "Playback \(step) failed (\(AudioDevices.statusString(status)))."
        }
    }
}

# SimpleEQ

SimpleEQ is a system-wide graphic EQ for macOS. It captures a loopback device, runs Apple's `AVAudioUnitEQ`, and plays the result on your speakers.

```
Apps → loopback device → AVAudioEngine input → AVAudioUnitEQ → speakers
```

## Requirements

- macOS 13 or later
- Xcode 16 or later
- A loopback driver for system-wide EQ. [BlackHole 2ch](https://github.com/ExistentialAudio/BlackHole) is the one this app looks for first.

```bash
brew install blackhole-2ch
```

## Build

Open `SimpleEQ.xcodeproj` and run the SimpleEQ scheme.

From the command line:

```bash
xcodebuild -project SimpleEQ.xcodeproj -scheme SimpleEQ -configuration Debug build
```

The project signs ad hoc, so a clone builds without an Apple Developer team. `project.yml` is the XcodeGen spec. Regenerate the project with `xcodegen generate` only after you edit that file.

## Use it

1. Install BlackHole 2ch.
2. Launch SimpleEQ.
3. Set Input to BlackHole and Output to your speakers or headphones.
4. Leave **Claim system output** on.
5. Click **Start**. Audio from other apps plays through the EQ.

**Claim system output** sets the system default output to the loopback device while SimpleEQ is running. Stop and Quit put the previous output back. If the app quits without restoring it, the next launch tries again.

Turn **Claim system output** off when you route audio into the loopback yourself. Do not use a Multi-Output Device that contains both your speakers and the loopback. You would hear the dry signal and the equalized signal together. If that Multi-Output Device is also SimpleEQ's output, the signal can loop.

SimpleEQ asks for microphone access because reading the loopback device is an audio input. It does not switch the system microphone.

## Layout

```
SimpleEQ/
├── Audio/
│   ├── AudioDevice.swift
│   ├── CircularBuffer.swift
│   ├── Engine.swift
│   ├── Equalizer.swift
│   └── PlaybackUnit.swift
├── AppModel.swift
├── ContentView.swift
├── SimpleEQApp.swift
├── Theme.swift
├── Info.plist
└── SimpleEQ.entitlements
```

## Left out on purpose

- A custom virtual driver. Use BlackHole.
- A per-app mixer
- A spectrum analyzer
- A fully parametric EQ
- Audio-unit hosting

## License

MIT. See `LICENSE`.

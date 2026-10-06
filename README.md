# SimpleEQ

SimpleEQ is a system-wide graphic EQ for macOS. It captures a loopback device, runs Apple's `AVAudioUnitEQ`, and plays the result on your speakers.

```
Apps → loopback → private aggregate (speaker clock) → AVAudioUnitEQ → speakers
```

## Requirements

- macOS 13 or later
- Swift 5.9 or later. Apple's Command Line Tools are enough (`xcode-select --install`); Xcode is not needed.
- A loopback driver for system-wide EQ. [BlackHole 2ch](https://github.com/ExistentialAudio/BlackHole) is the one this app looks for first.

```bash
brew install blackhole-2ch && sudo killall coreaudiod
```

The second command restarts Core Audio so macOS sees the new device. If BlackHole is missing, SimpleEQ shows this command with a Copy button.

## Build

```bash
./Scripts/build-app.sh
open build/SimpleEQ.app
```

The script runs `swift build`, wraps the binary in `build/SimpleEQ.app`, and signs it ad hoc with the hardened runtime and the audio-input entitlement, so a clone builds without an Apple Developer team. Set `SIGN_IDENTITY` to sign with a Developer ID, or `CONFIGURATION=debug` for a debug build.

## Use it

1. Install BlackHole 2ch.
2. Launch SimpleEQ.
3. Set Input to BlackHole and Output to your speakers or headphones.
4. Leave **Claim system output** on.
5. Click **Start**. Audio from other apps plays through the EQ.

**Claim system output** sets the system default output and the alert-sound output to the loopback device while SimpleEQ is running. It also moves your speakers' volume onto the loopback and runs the speakers at full, so the volume keys keep working and the loudness stays the same. Stop and Quit put the previous outputs and volumes back. If the app quits without restoring it, the next launch tries again. If the loopback or the speakers disappear while EQ is running, SimpleEQ stops and restores that output.

Turn **Claim system output** off when you route audio into the loopback yourself. Do not use a Multi-Output Device that contains both your speakers and the loopback. You would hear the dry signal and the equalized signal together. If that Multi-Output Device is also SimpleEQ's output, the signal can loop.

SimpleEQ asks for microphone access because reading the loopback device is an audio input. It does not switch the system microphone.

## Layout

```
Package.swift
Resources/
├── Info.plist
└── SimpleEQ.entitlements
Scripts/
└── build-app.sh
Sources/SimpleEQ/
├── Audio/
│   ├── AudioDevice.swift
│   ├── Engine.swift
│   └── Equalizer.swift
├── AppModel.swift
├── ContentView.swift
├── SimpleEQApp.swift
└── Theme.swift
```

## Left out on purpose

- A custom virtual driver. Use BlackHole.
- A per-app mixer
- A spectrum analyzer
- A fully parametric EQ
- Audio-unit hosting

## License

MIT. See `LICENSE`.

import os

struct RingCursors {
    var writePos: Int = 0
    var readPos: Int = 0
    var primed = false
}

final class CircularBuffer: @unchecked Sendable {
    private let capacity: Int
    private let mask: Int
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let primeFrames: Int
    private let state = OSAllocatedUnfairLock(initialState: RingCursors())

    init(capacityFrames: Int = 16384, primeFrames: Int = 2048) {
        let cap = Self.nextPow2(max(4096, capacityFrames))
        capacity = cap
        mask = cap - 1
        self.primeFrames = min(primeFrames, cap / 4)
        left = .allocate(capacity: cap)
        right = .allocate(capacity: cap)
        left.initialize(repeating: 0, count: cap)
        right.initialize(repeating: 0, count: cap)
    }

    deinit {
        left.deallocate()
        right.deallocate()
    }

    func reset() {
        state.withLockUnchecked { cursors in
            cursors.writePos = 0
            cursors.readPos = 0
            cursors.primed = false
            for i in 0..<capacity {
                left[i] = 0
                right[i] = 0
            }
        }
    }

    func write(left srcL: UnsafePointer<Float>, right srcR: UnsafePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }
        state.withLockUnchecked { cursors in
            var w = cursors.writePos
            let r = cursors.readPos
            for i in 0..<frameCount {
                if w &- r >= capacity { break }
                let idx = w & mask
                left[idx] = srcL[i]
                right[idx] = srcR[i]
                w &+= 1
            }
            cursors.writePos = w
        }
    }

    func read(left dstL: UnsafeMutablePointer<Float>, right dstR: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard frameCount > 0 else { return }
        state.withLockUnchecked { cursors in
            let filled = cursors.writePos &- cursors.readPos
            if !cursors.primed {
                if filled < primeFrames {
                    silence(dstL, dstR, frameCount)
                    return
                }
                cursors.primed = true
            }
            if filled < frameCount {
                cursors.readPos = cursors.writePos
                cursors.primed = false
                silence(dstL, dstR, frameCount)
                return
            }
            var r = cursors.readPos
            for i in 0..<frameCount {
                let idx = r & mask
                dstL[i] = left[idx]
                dstR[i] = right[idx]
                r &+= 1
            }
            cursors.readPos = r
        }
    }

    private func silence(_ dstL: UnsafeMutablePointer<Float>, _ dstR: UnsafeMutablePointer<Float>, _ frameCount: Int) {
        for i in 0..<frameCount {
            dstL[i] = 0
            dstR[i] = 0
        }
    }

    private static func nextPow2(_ v: Int) -> Int {
        var x = v - 1
        x |= x >> 1
        x |= x >> 2
        x |= x >> 4
        x |= x >> 8
        x |= x >> 16
        x |= x >> 32
        return x + 1
    }
}

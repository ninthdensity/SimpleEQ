import Foundation

struct EQPreset: Codable, Identifiable, Equatable {
    var name: String
    var bandCount: Engine.BandCount
    var gains: [Float]
    var preamp: Float

    var id: String { name }
}

enum PresetStore {
    private static let key = "simpleEQ.presets"

    static func load() -> [EQPreset] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let presets = try? JSONDecoder().decode([EQPreset].self, from: data) else { return [] }
        return presets
    }

    static func save(_ presets: [EQPreset]) {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

// EQSettings.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation

/// Persistent user-facing equalizer settings.
struct EQSettings: Codable, Equatable, Sendable {
    /// Minimum gain (dB) allowed on any band or on the preamp.
    static let minGainDB: Float = -12

    /// Maximum gain (dB) allowed on any band or on the preamp.
    static let maxGainDB: Float = 12

    var isEnabled: Bool
    var preampDB: Float
    var bandGainsDB: [Float]
    var preset: EQPreset

    static let flat = EQSettings(
        isEnabled: false,
        preampDB: 0,
        bandGainsDB: Array(repeating: 0, count: EQBand.defaultBands.count),
        preset: .flat
    )

    mutating func clampGains() {
        self.preampDB = min(max(self.preampDB, Self.minGainDB), Self.maxGainDB)
        let expected = EQBand.defaultBands.count
        if self.bandGainsDB.count < expected {
            self.bandGainsDB.append(contentsOf: Array(repeating: 0, count: expected - self.bandGainsDB.count))
        } else if self.bandGainsDB.count > expected {
            self.bandGainsDB = Array(self.bandGainsDB.prefix(expected))
        }
        self.bandGainsDB = self.bandGainsDB.map { min(max($0, Self.minGainDB), Self.maxGainDB) }
    }

    var autoTrimDB: Float {
        let peakBandGain = self.bandGainsDB.max() ?? 0
        let peak = self.preampDB + peakBandGain
        return -max(0, peak) * 0.2
    }
}

extension EQSettings {
    static func migrateLegacySettings(from defaults: UserDefaults) -> EQSettings? {
        let legacyStorageKey = "com.optitube.eqsettings"
        guard defaults.object(forKey: legacyStorageKey + ".enabled") != nil || defaults.object(forKey: legacyStorageKey) != nil else {
            return nil
        }
        
        let isEnabled = defaults.bool(forKey: legacyStorageKey + ".enabled")
        var preset: EQPreset = .flat
        var bandGainsDB = EQPreset.flat.bandGainsDB
        
        if let presetRaw = defaults.string(forKey: legacyStorageKey + ".preset") {
            switch presetRaw {
            case "Flat": preset = .flat
            case "Bass Boost": preset = .bassBooster
            case "Acoustic": preset = .acoustic
            case "Classical": preset = .classical
            case "Jazz": preset = .jazz
            case "Rock": preset = .rock
            case "Pop": preset = .pop
            case "Dance": preset = .dance
            case "Electronic": preset = .electronic
            case "Lounge": preset = .lounge
            case "Piano": preset = .piano
            case "Vocal Booster": preset = .vocalBooster
            default: preset = .flat
            }
            bandGainsDB = preset.bandGainsDB
        }
        
        struct LegacyBand: Codable {
            let frequency: Int
            let gain: Double
        }
        
        if let data = defaults.data(forKey: legacyStorageKey),
           let decoded = try? JSONDecoder().decode([LegacyBand].self, from: data) {
            let legacyGains = Dictionary(uniqueKeysWithValues: decoded.map { ($0.frequency, $0.gain) })
            
            let g60 = legacyGains[64] ?? 0
            let g150 = legacyGains[125] ?? 0
            let g400 = ((legacyGains[250] ?? 0) + (legacyGains[500] ?? 0)) / 2
            let g1000 = legacyGains[1000] ?? 0
            let g2400 = legacyGains[2000] ?? 0
            let g15000 = legacyGains[16000] ?? 0
            
            bandGainsDB = [Float(g60), Float(g150), Float(g400), Float(g1000), Float(g2400), Float(g15000)]
            preset = .custom
        }
        
        var settings = EQSettings(
            isEnabled: isEnabled,
            preampDB: 0,
            bandGainsDB: bandGainsDB,
            preset: preset
        )
        settings.clampGains()
        return settings
    }
}

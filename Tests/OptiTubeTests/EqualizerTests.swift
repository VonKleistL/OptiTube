// EqualizerTests.swift
// OptiTubeTests
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation
import Testing
@testable import OptiTube

@Suite("Equalizer Settings and Engine math")
struct EqualizerTests {
    @Test("EQSettings.flat starts disabled with neutral bands")
    func flatSettings() {
        let flat = EQSettings.flat
        #expect(!flat.isEnabled)
        #expect(flat.preampDB == 0)
        #expect(flat.bandGainsDB.allSatisfy { $0 == 0 })
        #expect(flat.preset == .flat)
        #expect(flat.autoTrimDB == 0)
    }

    @Test("EQSettings clamps preamp and band gains")
    func gainClamping() {
        var settings = EQSettings(
            isEnabled: true,
            preampDB: 20.0,
            bandGainsDB: [15.0, -15.0, 0, 0, 0, 0],
            preset: .custom
        )
        settings.clampGains()
        
        #expect(settings.preampDB == EQSettings.maxGainDB)
        #expect(settings.bandGainsDB[0] == EQSettings.maxGainDB)
        #expect(settings.bandGainsDB[1] == EQSettings.minGainDB)
        #expect(settings.bandGainsDB.count == EQBand.defaultBands.count)
    }

    @Test("autoTrimDB reserves correct headroom")
    func autoTrimHeadroom() {
        // Flat preset -> peak = 0 -> trim = 0
        #expect(EQSettings.flat.autoTrimDB == 0)

        // Peak band +6 dB, preamp 0 -> trim = -1.2 dB (-6 * 0.2)
        var s1 = EQSettings(isEnabled: true, preampDB: 0, bandGainsDB: [6.0, 0, 0, 0, 0, 0], preset: .custom)
        #expect(s1.autoTrimDB == -1.2)

        // Peak band +6 dB, preamp +6 dB -> peak = 12 -> trim = -2.4 dB
        var s2 = EQSettings(isEnabled: true, preampDB: 6.0, bandGainsDB: [6.0, 0, 0, 0, 0, 0], preset: .custom)
        #expect(s2.autoTrimDB == -2.4)

        // Negative peak -> trim = 0
        var s3 = EQSettings(isEnabled: true, preampDB: -6.0, bandGainsDB: [-2.0, -4.0, -6.0, -6.0, -6.0, -6.0], preset: .custom)
        #expect(s3.autoTrimDB == 0)
    }

    @Test("EQPreset lists match expected 6-band gains")
    func presetGains() {
        for preset in EQPreset.allCases {
            let gains = preset.bandGainsDB
            #expect(gains.count == EQBand.defaultBands.count)
            #expect(gains.allSatisfy { $0 >= EQSettings.minGainDB && $0 <= EQSettings.maxGainDB })
        }
    }
}

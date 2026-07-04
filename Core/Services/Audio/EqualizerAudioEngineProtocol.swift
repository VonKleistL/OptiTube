// EqualizerAudioEngineProtocol.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation

/// Audio-side surface that EqualizerService depends on.
protocol EqualizerAudioEngineProtocol: AnyObject {
    var isRunning: Bool { get }
    var hasObservedAudio: Bool { get }
    func start() -> Result<Void, EqualizerAudioEngine.StartFailure>
    func stop()
    func apply(isEnabled: Bool, preampDB: Float, bandGainsDB: [Float])
}

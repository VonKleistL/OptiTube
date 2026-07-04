// EqualizerService.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import CoreAudio
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class EqualizerService {
    static let shared = EqualizerService()

    enum Status: Equatable {
        case off
        case active
        case standby
        case permissionNeeded(message: String)
        case error(message: String)
    }

    private enum Keys {
        static let settings = "settings.equalizer"
    }

    var settings: EQSettings {
        didSet {
            guard self.settings != oldValue else { return }
            self.schedulePersist()
            self.syncEngine()
        }
    }

    private(set) var lastFailure: EqualizerAudioEngine.StartFailure?
    private var inferredPermissionDenial: Bool = false

    private let engine: any EqualizerAudioEngineProtocol

    @ObservationIgnored private var retryTask: Task<Void, Never>?
    @ObservationIgnored private var verificationTask: Task<Void, Never>?
    @ObservationIgnored private var persistTask: Task<Void, Never>?
    @ObservationIgnored private var deviceChangeTask: Task<Void, Never>?

    private let isPlaybackActive: @MainActor () -> Bool
    private let playbackProgress: @MainActor () -> TimeInterval
    private let hasCapturePermission: @MainActor () -> Bool
    private let requestCapturePermission: @MainActor () -> Bool

    private let logger = DiagnosticsLogger.equalizer

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static let persistDebounceInterval: Duration = .milliseconds(250)
    private static let tapVerificationPollInterval: Duration = .seconds(2)
    private static let tapVerificationProgressThreshold: TimeInterval = 8

    private var shouldRequestCapturePermissionOnNextStart: Bool = false
    private let defaults: UserDefaults

    init(
        engine: any EqualizerAudioEngineProtocol = EqualizerAudioEngine(),
        isPlaybackActive: @escaping @MainActor () -> Bool = { PlaybackStore.shared?.isPlaying ?? false },
        playbackProgress: @escaping @MainActor () -> TimeInterval = { PlaybackStore.shared?.progress ?? 0 },
        hasCapturePermission: @escaping @MainActor () -> Bool = { CGPreflightScreenCaptureAccess() },
        requestCapturePermission: @escaping @MainActor () -> Bool = { CGRequestScreenCaptureAccess() },
        defaults: UserDefaults = .standard
    ) {
        self.engine = engine
        self.isPlaybackActive = isPlaybackActive
        self.playbackProgress = playbackProgress
        self.hasCapturePermission = hasCapturePermission
        self.requestCapturePermission = requestCapturePermission
        self.defaults = defaults
        self.settings = Self.loadPersistedSettings(from: defaults)
        self.syncEngine()
        self.installDefaultOutputDeviceListener()
    }

    nonisolated private static let defaultOutputDeviceListener:
        @Sendable (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void = { _, _ in
            Task { @MainActor in
                EqualizerService.shared.handleDefaultOutputDeviceChange()
            }
        }

    private func installDefaultOutputDeviceListener() {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            Self.defaultOutputDeviceListener
        )
        if status != noErr {
            self.logger.warning("failed to listen for default-output changes: \(status)")
        }
    }

    private func handleDefaultOutputDeviceChange() {
        guard self.settings.isEnabled else { return }
        self.deviceChangeTask?.cancel()
        self.deviceChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            guard let self, !Task.isCancelled, self.settings.isEnabled else { return }
            self.logger.info("default output device changed — rebinding equalizer engine")
            self.engine.stop()
            self.attemptStart(playbackKnownActive: self.isPlaybackActive())
        }
    }

    func apply(preset: EQPreset) {
        var next = self.settings
        next.preset = preset
        next.bandGainsDB = preset.bandGainsDB
        next.clampGains()
        self.settings = next
    }

    func setGain(forBandAt index: Int, to gainDB: Float) {
        guard self.settings.bandGainsDB.indices.contains(index) else { return }
        var next = self.settings
        next.bandGainsDB[index] = gainDB
        next.preset = .custom
        next.clampGains()
        self.settings = next
    }

    func setPreamp(_ gainDB: Float) {
        var next = self.settings
        next.preampDB = gainDB
        next.clampGains()
        self.settings = next
    }

    func setEnabled(_ enabled: Bool) {
        self.inferredPermissionDenial = false
        self.shouldRequestCapturePermissionOnNextStart = enabled
        var next = self.settings
        next.isEnabled = enabled
        self.settings = next
    }

    func reset() {
        var next = EQSettings.flat
        next.isEnabled = self.settings.isEnabled
        self.settings = next
    }

    func retryStartIfEnabled() {
        guard self.settings.isEnabled, !self.engine.isRunning else { return }
        self.retryTask?.cancel()
        self.retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, !Task.isCancelled,
                  self.settings.isEnabled, !self.engine.isRunning
            else { return }
            self.attemptStart(playbackKnownActive: true)
        }
    }

    var status: Status {
        if self.inferredPermissionDenial {
            return .permissionNeeded(message: String(
                localized: "Open System Settings → Privacy & Security → Screen & System Audio Recording and enable OptiTube, then retry playback or toggle the equalizer off and on."
            ))
        }
        guard self.settings.isEnabled else { return .off }
        if self.engine.isRunning { return .active }
        if let failure = self.lastFailure {
            if failure.isPermissionLikely {
                return .permissionNeeded(message: failure.userFacingMessage)
            }
            return .error(message: failure.userFacingMessage)
        }
        return .standby
    }

    private func schedulePersist() {
        self.persistTask?.cancel()
        self.persistTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.persistDebounceInterval)
            guard let self, !Task.isCancelled else { return }
            self.persist()
        }
    }

    private func persist() {
        do {
            let data = try Self.encoder.encode(self.settings)
            self.defaults.set(data, forKey: Keys.settings)
        } catch {
            self.logger.error("persist failed: \(error.localizedDescription)")
        }
    }

    private static func loadPersistedSettings(from defaults: UserDefaults) -> EQSettings {
        if let data = defaults.data(forKey: Keys.settings) {
            do {
                var decoded = try Self.decoder.decode(EQSettings.self, from: data)
                decoded.clampGains()
                return decoded
            } catch {
                DiagnosticsLogger.equalizer.warning("failed to decode stored settings: \(error.localizedDescription)")
            }
        }
        
        if let migrated = EQSettings.migrateLegacySettings(from: defaults) {
            return migrated
        }
        
        return .flat
    }

    private func syncEngine() {
        if self.settings.isEnabled {
            self.attemptStart(playbackKnownActive: false)
        } else {
            self.retryTask?.cancel()
            self.verificationTask?.cancel()
            self.deviceChangeTask?.cancel()
            self.engine.stop()
            self.lastFailure = nil
        }
    }

    private func attemptStart(playbackKnownActive: Bool) {
        if !self.hasCapturePermission() {
            if self.shouldRequestCapturePermissionOnNextStart {
                self.shouldRequestCapturePermissionOnNextStart = false
                _ = self.requestCapturePermission()
                guard self.hasCapturePermission() else {
                    self.logger.warning("capture permission request did not grant access yet")
                    self.flagPermissionDenial()
                    return
                }
            } else {
                self.logger.warning("capture permission missing — awaiting explicit user retry")
                self.flagPermissionDenial()
                return
            }
        }
        self.shouldRequestCapturePermissionOnNextStart = false

        switch self.engine.start() {
        case .success:
            self.lastFailure = nil
            self.inferredPermissionDenial = false
            self.engine.apply(
                isEnabled: self.settings.isEnabled,
                preampDB: self.settings.preampDB,
                bandGainsDB: self.settings.bandGainsDB
            )
            self.scheduleTapVerification()
        case let .failure(failure):
            if failure.isWaitingForPlayback, !playbackKnownActive {
                self.lastFailure = nil
            } else if failure.isWaitingForPlayback, playbackKnownActive {
                self.logger.warning("process scan empty while playback active — inferring permission denial")
                self.flagPermissionDenial()
            } else if failure.isPermissionLikely {
                self.logger.warning("permission failure — \(String(describing: failure))")
                self.flagPermissionDenial()
            } else {
                self.logger.warning("start failed — \(String(describing: failure))")
                self.lastFailure = failure
            }
        }
    }

    private func flagPermissionDenial() {
        self.verificationTask?.cancel()
        self.inferredPermissionDenial = true
        self.lastFailure = nil
        self.engine.stop()
    }

    private func scheduleTapVerification() {
        self.verificationTask?.cancel()
        let initialProgress = self.playbackProgress()
        self.verificationTask = Task { @MainActor [weak self, initialProgress] in
            while true {
                try? await Task.sleep(for: Self.tapVerificationPollInterval)
                guard let self, !Task.isCancelled,
                      self.engine.isRunning, self.settings.isEnabled
                else { return }
                if self.engine.hasObservedAudio {
                    return
                }
                guard self.isPlaybackActive() else { continue }

                let progressedPlayback = max(0, self.playbackProgress() - initialProgress)
                guard progressedPlayback >= Self.tapVerificationProgressThreshold else { continue }
                let progressedPlaybackString = String(format: "%.1f", progressedPlayback)

                self.logger.warning("tap stayed silent for \(progressedPlaybackString)s of active playback — inferring permission denial")
                self.flagPermissionDenial()
                return
            }
        }
    }
}

// AppSource.swift
// OptiTube
//
// Copyright (c) 2025 VonKleistL. Licensed under MIT License.
//

import Foundation

/// The active content source for the app-wide experience.
enum AppSource: String, CaseIterable, Identifiable {
    /// The YouTube Music experience (default).
    case music

    /// The regular YouTube video experience.
    case video

    /// The YouTube Studio creator experience.
    case studio

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .music:
            String(localized: "Music")
        case .video:
            String(localized: "YouTube")
        case .studio:
            String(localized: "Studio")
        }
    }

    /// SF Symbol shown on the source toggle segment.
    var icon: String {
        switch self {
        case .music:
            "music.note"
        case .video:
            "play.rectangle.fill"
        case .studio:
            "slider.horizontal.3"
        }
    }
}

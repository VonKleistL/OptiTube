import Foundation
import AVFoundation
import Observation

/// A service that monitors AirPlay routing and connectivity.
@MainActor
@Observable
final class AirPlayService {
    static let shared = AirPlayService()
    
    /// Whether AirPlay is currently active.
    var isAirPlayActive: Bool = false
    
    private init() {
        // macOS handles audio routing at the system level.
        // We can manually toggle this state when the user selects a device via the picker.
    }
    
    /// Updated by the AirPlay picker or system notifications.
    func setAirPlayActive(_ active: Bool) {
        self.isAirPlayActive = active
    }
}

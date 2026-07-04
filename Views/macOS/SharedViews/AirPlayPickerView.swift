import SwiftUI
import AVKit

/// A SwiftUI wrapper for AVRoutePickerView.
struct AirPlayPickerView: NSViewRepresentable {
    func makeNSView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        return picker
    }
    
    func updateNSView(_ nsView: AVRoutePickerView, context: Context) {}
}

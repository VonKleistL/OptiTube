import SwiftUI

/// A professional mixing board UI for the 6-band parametric EQ, bound to EqualizerService.
struct EqualizerView: View {
    @Bindable var service = EqualizerService.shared
    
    private var availablePresets: [EQPreset] {
        var list = EQPreset.pickerOrder
        if self.service.settings.preset == .custom {
            list.append(.custom)
        }
        return list
    }
    
    private var isEnabled: Binding<Bool> {
        Binding(
            get: { self.service.settings.isEnabled },
            set: { self.service.setEnabled($0) }
        )
    }

    private var preset: Binding<EQPreset> {
        Binding(
            get: { self.service.settings.preset },
            set: { self.service.apply(preset: $0) }
        )
    }

    private var preamp: Binding<Float> {
        Binding(
            get: { self.service.settings.preampDB },
            set: { self.service.setPreamp($0) }
        )
    }

    private func gainBinding(forBandAt index: Int) -> Binding<Float> {
        Binding(
            get: { self.service.settings.bandGainsDB[safe: index] ?? 0 },
            set: { self.service.setGain(forBandAt: index, to: $0) }
        )
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header with master toggle and presets
            HStack {
                Text("Equalizer")
                    .font(.headline)
                
                Spacer()
                
                Picker("Preset", selection: self.preset) {
                    ForEach(availablePresets) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .disabled(!service.settings.isEnabled)
                .frame(width: 140)
                
                Toggle("Enabled", isOn: self.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 4)
            
            // EQ Status Banner
            statusBanner
            
            // Mixing Board Bands + Preamp
            HStack(spacing: 12) {
                // Preamp Slider
                VStack(spacing: 8) {
                    Text(formatGain(service.settings.preampDB))
                        .font(.system(size: 9, design: .monospaced))
                        .frame(width: 32)
                        .foregroundStyle(service.settings.preampDB != 0 ? Color.appAccent : .secondary)
                    
                    Slider(
                        value: Binding(
                            get: { Double(service.settings.preampDB) },
                            set: { service.setPreamp(Float($0)) }
                        ),
                        in: -12...12
                    )
                    .controlSize(.small)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 100, height: 20)
                    .offset(y: 40)
                    .frame(width: 32, height: 100)
                    .tint(.secondary)
                    
                    Text("Preamp")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .disabled(!service.settings.isEnabled)
                .opacity(service.settings.isEnabled ? 1.0 : 0.5)
                
                Divider()
                    .frame(height: 120)
                
                // 6 bands
                ForEach(0..<EQBand.defaultBands.count, id: \.self) { index in
                    let band = EQBand.defaultBands[index]
                    let gain = service.settings.bandGainsDB[safe: index] ?? 0
                    
                    VStack(spacing: 8) {
                        // DB Label
                        Text(formatGain(gain))
                            .font(.system(size: 9, design: .monospaced))
                            .frame(width: 32)
                            .foregroundStyle(gain != 0 ? Color.appAccent : .secondary)
                        
                        // Vertical Slider
                        Slider(
                            value: Binding(
                                get: { Double(gain) },
                                set: { service.setGain(forBandAt: index, to: Float($0)) }
                            ),
                            in: -12...12
                        )
                        .controlSize(.small)
                        .rotationEffect(.degrees(-90))
                        .frame(width: 100, height: 20)
                        .offset(y: 40)
                        .frame(width: 32, height: 100)
                        .tint(.appAccent)
                        
                        // Frequency Label
                        Text(band.displayLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .disabled(!service.settings.isEnabled)
                    .opacity(service.settings.isEnabled ? 1.0 : 0.5)
                }
            }
            .padding(.bottom, 4)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }
    
    @ViewBuilder
    private var statusBanner: some View {
        let status = service.status
        if status != .off {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: status))
                    .foregroundStyle(iconColor(for: status))
                    .font(.system(size: 11))
                
                Text(statusText(for: status))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    
                Spacer()
                
                if case .permissionNeeded = status {
                    Button("Open Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private func iconName(for status: EqualizerService.Status) -> String {
        switch status {
        case .off: "power.circle"
        case .active: "checkmark.circle.fill"
        case .standby: "pause.circle"
        case .permissionNeeded: "lock.shield"
        case .error: "exclamationmark.triangle.fill"
        }
    }
    
    private func iconColor(for status: EqualizerService.Status) -> Color {
        switch status {
        case .off: .secondary
        case .active: .green
        case .standby: .appAccent
        case .permissionNeeded: .orange
        case .error: .red
        }
    }
    
    private func statusText(for status: EqualizerService.Status) -> String {
        switch status {
        case .off:
            return "Equalizer Off"
        case .active:
            return "Active"
        case .standby:
            return "Waiting for playback"
        case .permissionNeeded:
            return "Permission required"
        case let .error(msg):
            return "Error: \(msg)"
        }
    }
    
    private func formatGain(_ gain: Float) -> String {
        let intVal = Int(round(gain))
        if intVal > 0 {
            return "+\(intVal)"
        }
        return "\(intVal)"
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

import SwiftUI

/// Settings view for general app preferences and themes.
@available(macOS 15.0, *)
struct GeneralSettingsView: View {
    @Environment(AuthService.self) private var authService
    @State private var settings = SettingsManager.shared
    @State private var cacheSize: String = L("Calculating...")
    @State private var isClearing = false

    var body: some View {
        Form {
            // MARK: - General Section
            Section {
                // Account status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Account"))
                            .font(.headline)
                        Text(self.accountStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if self.authService.state.isLoggedIn {
                        Button(L("Sign Out")) {
                            Task {
                                await self.authService.signOut()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)

                // Now Playing Notifications
                Toggle(L("Show Now Playing Notifications"), isOn: self.$settings.showNowPlayingNotifications)

                // Haptic Feedback
                Toggle(L("Haptic Feedback"), isOn: self.$settings.hapticFeedbackEnabled)
                    .help(L("Provide tactile feedback for actions on Force Touch trackpads"))

                // Synced Lyrics
                Toggle(L("Enable Synced Lyrics"), isOn: self.$settings.syncedLyricsEnabled)
                    .help(L("Fetch and display real-time synced lyrics when available"))

                // Remember Playback Settings
                Toggle(L("Remember Shuffle & Repeat"), isOn: self.$settings.rememberPlaybackSettings)
                    .help(L("Save shuffle and repeat settings across app restarts"))

                // Now Playing Controls
                Picker(L("Now Playing Controls"), selection: self.$settings.mediaControlStyle) {
                    ForEach(SettingsManager.MediaControlStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .help(L("Choose which command style is used by Control Center media controls"))

                // Default Launch Page
                Picker(L("Default Page on Launch"), selection: self.$settings.defaultLaunchPage) {
                    ForEach(SettingsManager.LaunchPage.allCases) { page in
                        Text(page.displayName).tag(page)
                    }
                }

                // Image Cache
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Image Cache"))
                        Text(self.cacheSize)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(self.isClearing ? L("Clearing...") : L("Clear Cache")) {
                        Task {
                            await self.clearCache()
                        }
                    }
                    .disabled(self.isClearing)
                }
                .padding(.vertical, 4)
            } header: {
                Text(L("General"))
            }

            // MARK: - Appearance Section
            Section {
                Picker(L("Visual Theme"), selection: self.$settings.currentTheme) {
                    ForEach(SettingsManager.AppTheme.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.radioGroup)
            } header: {
                Text(L("App Appearance"))
            }

            // MARK: - About Section
            Section {
                HStack {
                    Text(L("Version"))
                    Spacer()
                    Text(self.appVersion)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(L("About"))
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 400, minHeight: 300)
        .navigationTitle(L("General"))
        .task {
            await self.updateCacheSize()
        }
    }

    // MARK: - Computed Properties

    private var accountStatusText: String {
        self.authService.state.isLoggedIn ? L("Signed in to YouTube Music") : L("Not signed in")
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? L("Unknown")
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }

    // MARK: - Actions

    private func updateCacheSize() async {
        let size = await ImageCache.shared.diskCacheSize()
        self.cacheSize = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func clearCache() async {
        self.isClearing = true
        await ImageCache.shared.clearAllCaches()
        await self.updateCacheSize()
        self.isClearing = false
    }
}

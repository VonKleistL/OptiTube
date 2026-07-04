import Foundation
import Testing
@testable import OptiTube

/// Tests for utility extensions.
@Suite("Extensions", .tags(.model))
struct ExtensionsTests {
    private func makeBundle(
        named name: String,
        at parentDirectory: URL,
        localizations: [String: [String: String]]
    ) throws -> Bundle {
        let bundleURL = parentDirectory.appendingPathComponent(name)
        let resourcesURL = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)

        let infoPlist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.optitube.tests.\(name.replacingOccurrences(of: ".", with: "-"))</string>
            <key>CFBundleName</key>
            <string>\(name)</string>
            <key>CFBundlePackageType</key>
            <string>BNDL</string>
        </dict>
        </plist>
        """
        try infoPlist.write(
            to: bundleURL.appendingPathComponent("Contents/Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        for (languageCode, strings) in localizations {
            let localizationDirectory = resourcesURL.appendingPathComponent("\(languageCode).lproj", isDirectory: true)
            try FileManager.default.createDirectory(at: localizationDirectory, withIntermediateDirectories: true)

            let content = strings
                .sorted(by: { $0.key < $1.key })
                .map { "\"\($0.key)\" = \"\($0.value)\";" }
                .joined(separator: "\n")
            try content.write(
                to: localizationDirectory.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
        }

        guard let bundle = Bundle(path: bundleURL.path) else {
            Issue.record("Failed to open bundle at \(bundleURL.path)")
            throw CocoaError(.fileReadCorruptFile)
        }
        return bundle
    }

    // MARK: - Collection Safe Subscript Tests

    @Test("Safe subscript returns value for valid indices")
    func arraySafeSubscriptInBounds() {
        let array = [1, 2, 3, 4, 5]
        #expect(array[safe: 0] == 1)
        #expect(array[safe: 2] == 3)
        #expect(array[safe: 4] == 5)
    }

    @Test("Safe subscript returns nil for out of bounds indices")
    func arraySafeSubscriptOutOfBounds() {
        let array = [1, 2, 3]
        #expect(array[safe: 3] == nil)
        #expect(array[safe: 10] == nil)
        #expect(array[safe: -1] == nil)
    }

    @Test("Safe subscript returns nil for empty array")
    func arraySafeSubscriptEmptyArray() {
        let array: [Int] = []
        #expect(array[safe: 0] == nil)
    }

    @Test("Safe subscript works with character arrays")
    func stringSafeSubscript() {
        let string = "Hello"
        let array = Array(string)
        #expect(array[safe: 0] == "H")
        #expect(array[safe: 4] == "o")
        #expect(array[safe: 5] == nil)
    }

    // MARK: - TimeInterval Formatted Duration Tests

    @Test(
        "Formats seconds correctly",
        arguments: [
            (0.0, "0:00"),
            (5.0, "0:05"),
            (59.0, "0:59"),
        ]
    )
    func formattedDurationSeconds(seconds: TimeInterval, expected: String) {
        #expect(seconds.formattedDuration == expected)
    }

    @Test(
        "Formats minutes correctly",
        arguments: [
            (60.0, "1:00"),
            (65.0, "1:05"),
            (125.0, "2:05"),
            (3599.0, "59:59"),
        ]
    )
    func formattedDurationMinutes(seconds: TimeInterval, expected: String) {
        #expect(seconds.formattedDuration == expected)
    }

    @Test(
        "Formats hours correctly",
        arguments: [
            (3600.0, "1:00:00"),
            (3661.0, "1:01:01"),
            (7325.0, "2:02:05"),
            (36000.0, "10:00:00"),
        ]
    )
    func formattedDurationHours(seconds: TimeInterval, expected: String) {
        #expect(seconds.formattedDuration == expected)
    }

    @Test("Truncates decimal seconds")
    func formattedDurationDecimal() {
        #expect(TimeInterval(65.5).formattedDuration == "1:05")
        #expect(TimeInterval(65.9).formattedDuration == "1:05")
    }

    // MARK: - URL High Quality Thumbnail Tests

    @Test("Upgrades ytimg URL to high quality")
    func highQualityThumbnailYtimg() {
        let url = URL(string: "https://i.ytimg.com/vi/abc/w60-h60-l90-rj")!
        let highQuality = url.highQualityThumbnailURL
        #expect(highQuality != nil)
        #expect(highQuality!.absoluteString.contains("w226-h226"))
    }

    @Test("Upgrades googleusercontent URL to high quality")
    func highQualityThumbnailGoogleusercontent() {
        let url = URL(string: "https://lh3.googleusercontent.com/abc=w120-h120-l90-rj")!
        let highQuality = url.highQualityThumbnailURL
        #expect(highQuality != nil)
        #expect(highQuality!.absoluteString.contains("w226-h226"))
    }

    @Test("Returns original URL for non-YouTube URLs")
    func highQualityThumbnailNonYouTubeURL() {
        let url = URL(string: "https://example.com/image.jpg")!
        let highQuality = url.highQualityThumbnailURL
        #expect(highQuality == url)
    }

    @Test("Returns same URL for already high quality thumbnails")
    func highQualityThumbnailAlreadyHighQuality() {
        let url = URL(string: "https://i.ytimg.com/vi/abc/w400-h400-l90-rj")!
        let highQuality = url.highQualityThumbnailURL
        #expect(highQuality?.absoluteString == "https://i.ytimg.com/vi/abc/w400-h400-l90-rj")
    }

    // MARK: - String Truncated Tests

    @Test("Returns full string when shorter than limit")
    func stringTruncatedShorterThanLimit() {
        let string = "Hello"
        #expect(string.truncated(to: 10) == "Hello")
    }

    @Test("Returns full string when exactly at limit")
    func stringTruncatedExactlyAtLimit() {
        let string = "Hello"
        #expect(string.truncated(to: 5) == "Hello")
    }

    @Test("Truncates with ellipsis when longer than limit")
    func stringTruncatedLongerThanLimit() {
        let string = "Hello, World!"
        #expect(string.truncated(to: 5) == "Hello…")
    }

    @Test("Uses custom trailing string")
    func stringTruncatedWithCustomTrailing() {
        let string = "Hello, World!"
        #expect(string.truncated(to: 5, trailing: "...") == "Hello...")
    }

    @Test("Handles empty string")
    func stringTruncatedEmptyString() {
        let string = ""
        #expect(string.truncated(to: 10).isEmpty)
    }

    @Test("Handles zero length")
    func stringTruncatedZeroLength() {
        let string = "Hello"
        #expect(string.truncated(to: 0) == "…")
    }

    @Test("Handles one character")
    func stringTruncatedOneCharacter() {
        let string = "Hello"
        #expect(string.truncated(to: 1) == "H…")
    }

    // MARK: - Localization Helpers

    @Test("AppLocalization resolves a localized string")
    func appLocalizationResolvesString() {
        let value = AppLocalization.string("Home")
        #expect(!value.isEmpty)
    }

    @Test("String localized initializer uses AppLocalization bundle")
    func stringLocalizedInitializerUsesAppLocalization() {
        let value = String(localized: "Search")
        let direct = AppLocalization.string("Search")
        #expect(value == direct)
    }

    @Test("AppLocalization has a valid fallback bundle")
    func appLocalizationHasValidBundle() {
        #expect(AppLocalization.bundle.bundleURL.isFileURL)
    }

    @Test("PackageResourceLookup finds nested localization bundles in packaged layouts")
    func packageResourceLookupFindsNestedBundle() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let hostBundle = try self.makeBundle(
            named: "Host.bundle",
            at: tempDirectory,
            localizations: [:]
        )
        let resourcesDirectory = hostBundle.bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let localizationBundle = try self.makeBundle(
            named: "OptiTube.bundle",
            at: resourcesDirectory,
            localizations: ["tr": ["Play": "Oynat"]]
        )

        let resolved = PackageResourceLookup.findLocalizationBundle(
            in: [hostBundle],
            resourceBundleNames: ["OptiTube.bundle"],
            preferMainBundle: false
        )

        #expect(resolved?.bundleURL == localizationBundle.bundleURL)
        #expect(resolved?.localizations.contains("tr") == true)
    }

    @Test("AppLocalization resolves strings from an injected bundle")
    func appLocalizationUsesInjectedBundle() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let bundle = try self.makeBundle(
            named: "Injected.bundle",
            at: tempDirectory,
            localizations: ["tr": ["Play": "Oynat"]]
        )

        let value = AppLocalization.string("Play", bundle: bundle, preferredLanguageCode: "tr")
        #expect(value == "Oynat")
    }

    @Test("AppLocalization falls back to embedded translations when bundle misses a key")
    func appLocalizationFallsBackToEmbeddedTranslations() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let bundle = try self.makeBundle(
            named: "Fallback.bundle",
            at: tempDirectory,
            localizations: [:]
        )

        let value = AppLocalization.string("Play Album", bundle: bundle, preferredLanguageCode: "tr")
        #expect(value == "Albümü Çal")
    }
}

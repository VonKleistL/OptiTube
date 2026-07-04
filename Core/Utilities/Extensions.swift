import AppKit
import Foundation
import SwiftUI

// MARK: - Notification Extensions

extension Notification.Name {
    /// Posted when the active user account changes.
    static let userAccountDidChange = Notification.Name("userAccountDidChange")
}

// MARK: - Collection Extensions

extension Collection {
    /// Safe subscript that returns nil if index is out of bounds.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// Formats the time interval as "mm:ss" or "h:mm:ss".
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a modifier conditionally.
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    /// Applies a modifier if a value is present.
    @ViewBuilder
    func ifLet<Value>(_ value: Value?, transform: (Self, Value) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - URL Extensions

extension URL {
    /// Returns a higher quality YouTube thumbnail URL.
    var highQualityThumbnailURL: URL? {
        guard host?.contains("ytimg.com") == true || host?.contains("googleusercontent.com") == true else {
            return self
        }

        var urlString = absoluteString

        // Replace size parameters for higher quality
        urlString = urlString.replacingOccurrences(of: "w60-h60", with: "w226-h226")
        urlString = urlString.replacingOccurrences(of: "w120-h120", with: "w226-h226")

        return URL(string: urlString)
    }
}

// MARK: - String Extensions

extension String {
    /// Returns a truncated version of the string.
    func truncated(to length: Int, trailing: String = "…") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
}

// MARK: - Color Extensions

extension Color {
    /// Creates a Color from a hex string (e.g., "#FF5733" or "FF5733").
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        switch length {
        case 6: // RGB
            let red = Double((rgb >> 16) & 0xFF) / 255.0
            let green = Double((rgb >> 8) & 0xFF) / 255.0
            let blue = Double(rgb & 0xFF) / 255.0
            self.init(red: red, green: green, blue: blue)
        case 8: // ARGB
            let red = Double((rgb >> 16) & 0xFF) / 255.0
            let green = Double((rgb >> 8) & 0xFF) / 255.0
            let blue = Double(rgb & 0xFF) / 255.0
            let alpha = Double((rgb >> 24) & 0xFF) / 255.0
            self.init(red: red, green: green, blue: blue, opacity: alpha)
        default:
            return nil
        }
    }
}

// MARK: - Package Resource Lookup

/// Resolves resource bundles in app, framework, and SwiftPM-style packaged layouts.
enum PackageResourceLookup {
    private static let candidateResourceBundleNames = [
        "OptiTube_OptiTube.bundle",
        "OptiTube_OptiTube.bundle",
        "OptiTube.bundle",
        "OptiTube.bundle",
    ]

    private static let accentColorName = NSColor.Name("AccentColor")

    static let localizationBundle: Bundle? = Self.findLocalizationBundle(
        in: Self.candidateBundles,
        resourceBundleNames: Self.candidateResourceBundleNames
    )

    static let brandAccent: Color = {
        if let mainColor = NSColor(named: accentColorName, bundle: .main) {
            return Color(nsColor: mainColor)
        }

        for bundle in Self.candidateBundles {
            if let color = NSColor(named: accentColorName, bundle: bundle) {
                return Color(nsColor: color)
            }
        }

        return Color(red: 0.6, green: 0.4, blue: 1.0)
    }()

    private static let candidateBundles: [Bundle] = {
        var bundles: [Bundle] = [.main]
        bundles.append(contentsOf: Bundle.allBundles)
        bundles.append(contentsOf: Bundle.allFrameworks)

        var uniqueBundles: [Bundle] = []
        var seenPaths = Set<String>()
        for bundle in bundles {
            guard seenPaths.insert(bundle.bundleURL.path).inserted else { continue }
            uniqueBundles.append(bundle)
        }
        return uniqueBundles
    }()

    static func findLocalizationBundle(
        in candidateBundles: [Bundle],
        resourceBundleNames: [String],
        preferMainBundle: Bool = true
    ) -> Bundle? {
        if preferMainBundle, !Bundle.main.localizations.isEmpty {
            return .main
        }

        for bundle in candidateBundles where bundle.bundleIdentifier?.localizedCaseInsensitiveContains("optitube") == true {
            if !bundle.localizations.isEmpty {
                return bundle
            }
        }

        for bundle in candidateBundles {
            for resourceName in resourceBundleNames {
                let candidateURLs: [URL?] = [
                    bundle.resourceURL?.appendingPathComponent(resourceName),
                    bundle.bundleURL.appendingPathComponent(resourceName),
                    bundle.bundleURL.deletingLastPathComponent().appendingPathComponent(resourceName),
                    bundle.executableURL?.deletingLastPathComponent().appendingPathComponent(resourceName),
                ]

                for candidateURL in candidateURLs.compactMap(\.self) {
                    if let resourceBundle = Bundle(url: candidateURL), !resourceBundle.localizations.isEmpty {
                        return resourceBundle
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - App Localization

/// Centralized localization entry point that survives packaged resource layouts.
enum AppLocalization {
    static let bundle = PackageResourceLookup.localizationBundle ?? Bundle.main

    private static let fallbackTranslations: [String: [String: String]] = [
        "tr": [
            "Play Next": "Sonraki Olarak Çal",
            "Add to Queue": "Sıraya Ekle",
            "Play Album": "Albümü Çal",
            "Add Album Next": "Albümü Sıradaki Olarak Ekle",
            "Add Album to End": "Albümü Sıranın Sonuna Ekle",
            "Enable Synced Lyrics": "Zaman Senkronlu Şarkı Sözlerini Etkinleştir",
            "Fetch and display real-time synced lyrics when available": "Uygun olduğunda gerçek zamanlı senkronlu şarkı sözlerini getir ve göster",
            "Now Playing Controls": "Şu An Çalan Denetimleri",
            "Choose which command style is used by Control Center media controls": "Denetim Merkezi medya denetimlerinde kullanılacak komut stilini seçin",
            "Skip Forward/Backward": "İleri/Geri Atla",
            "Next/Previous Track": "Sonraki/Önceki Parça",
            "What's New in OptiTube": "OptiTube'da Neler Yeni",
            "What's New in OptiTube %@": "OptiTube'da Neler Yeni %@",
            "What's New": "Neler Yeni",
            "Version %@": "Sürüm %@",
            "Learn More": "Daha Fazla Bilgi",
            "Continue": "Devam Et",
            "Lyrics": "Şarkı Sözleri",
            "Loading lyrics...": "Şarkı sözleri yükleniyor...",
            "Analyzing...": "Analiz ediliyor...",
            "Retry": "Tekrar Dene",
            "No Lyrics Available": "Şarkı Sözü Yok",
            "There aren't any lyrics available for this track.": "Bu parça için kullanılabilir şarkı sözü yok.",
            "No Track Playing": "Çalan Parça Yok",
            "Play a track to view its lyrics here.": "Şarkı sözlerini burada görmek için bir parça çalın.",
            "Explain lyrics with AI": "Şarkı sözlerini yapay zekayla açıkla",
            "Hide lyrics explanation": "Şarkı sözü açıklamasını gizle",
            "Apple Intelligence is not available": "Apple Intelligence kullanılamıyor",
        ],
        "ar": [
            "Play Next": "تشغيل التالي",
            "Add to Queue": "إضافة إلى قائمة الانتظار",
            "Play Album": "تشغيل الألبوم",
            "Add Album Next": "إضافة الألبوم للتشغيل التالي",
            "Add Album to End": "إضافة الألبوم إلى نهاية قائمة الانتظار",
            "Enable Synced Lyrics": "تمكين كلمات الأغاني المتزامنة",
            "Fetch and display real-time synced lyrics when available": "جلب وعرض كلمات الأغاني المتزامنة في الوقت الفعلي عند توفرها",
            "Now Playing Controls": "عناصر تحكم التشغيل الآن",
            "Choose which command style is used by Control Center media controls": "اختر نمط الأوامر المستخدم في عناصر تحكم الوسائط بمركز التحكم",
            "Skip Forward/Backward": "تخطي للأمام/للخلف",
            "Next/Previous Track": "المقطع التالي/السابق",
            "What's New in OptiTube": "ما الجديد في OptiTube",
            "What's New in OptiTube %@": "ما الجديد في OptiTube %@",
            "What's New": "ما الجديد",
            "Version %@": "الإصدار %@",
            "Learn More": "معرفة المزيد",
            "Continue": "متابعة",
            "Lyrics": "كلمات الأغنية",
            "Loading lyrics...": "جارٍ تحميل الكلمات...",
            "Analyzing...": "جاري التحليل...",
            "Retry": "إعادة المحاولة",
            "No Lyrics Available": "لا تتوفر كلمات",
            "There aren't any lyrics available for this track.": "لا تتوفر كلمات لهذه الأغنية.",
            "No Track Playing": "لا يوجد مقطع قيد التشغيل",
            "Play a track to view its lyrics here.": "شغّل مقطعًا لعرض كلماته هنا.",
            "Explain lyrics with AI": "شرح الكلمات بالذكاء الاصطناعي",
            "Hide lyrics explanation": "إخفاء شرح الكلمات",
            "Apple Intelligence is not available": "ذكاء Apple غير متاح",
        ],
    ]

    private static func preferredLanguageCode() -> String {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        let normalized = preferred
            .replacingOccurrences(of: "_", with: "-")
            .split(separator: "-")
            .first
            .map(String.init)?
            .lowercased()

        if normalized == "tr" || normalized == "ar" {
            return normalized ?? "en"
        }
        return "en"
    }

    static func string(_ key: String.LocalizationValue) -> String {
        let resolved = String(localized: key, bundle: Self.bundle)
        let fallbackKey = String(describing: key)
        if resolved == fallbackKey {
            return Self.string(fallbackKey)
        }
        return resolved
    }

    static func string(_ key: String) -> String {
        Self.string(key, bundle: Self.bundle)
    }

    static func string(
        _ key: String,
        bundle: Bundle,
        preferredLanguageCode: String? = nil
    ) -> String {
        let localized = NSLocalizedString(
            key,
            tableName: "Localizable",
            bundle: bundle,
            value: key,
            comment: ""
        )
        if localized != key {
            return localized
        }

        let languageCode = preferredLanguageCode ?? Self.preferredLanguageCode()
        return Self.fallbackTranslations[languageCode]?[key] ?? key
    }
}

extension String {
    init(localized key: LocalizationValue) {
        self = AppLocalization.string(key)
    }
}

private extension NSLock {
    func withLock<Result>(_ body: () -> Result) -> Result {
        self.lock()
        defer { self.unlock() }
        return body()
    }
}

/// Thread-safe task storage for actor-isolated types that still need cancellation in `deinit`.
final class TaskBox<Success: Sendable, Failure: Error & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Task<Success, Failure>?

    func replace(with task: Task<Success, Failure>?) {
        let previousTask = self.lock.withLock {
            let previousTask = self.task
            self.task = task
            return previousTask
        }
        previousTask?.cancel()
    }

    func cancel() {
        self.replace(with: nil)
    }
}

/// Thread-safe task collection storage for fan-out child tasks.
final class TaskCollectionBox<Success: Sendable, Failure: Error & Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Success, Failure>] = []

    func append(_ task: Task<Success, Failure>) {
        self.lock.withLock {
            self.tasks.append(task)
        }
    }

    func cancelAll() {
        let tasksToCancel = self.lock.withLock {
            let tasksToCancel = self.tasks
            self.tasks.removeAll()
            return tasksToCancel
        }
        tasksToCancel.forEach { $0.cancel() }
    }
}

/// Convenience helper for localized UI strings.
@inline(__always)
func L(_ key: String) -> String {
    AppLocalization.string(key)
}

/// Convenience helper for localized format strings.
@inline(__always)
func LF(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: AppLocalization.string(key), locale: Locale.current, arguments: arguments)
}

import WebKit
import Foundation
import Observation
import os

/// Extracts live context (`ytcfg` and `ytInitialData`) from a hidden WebView.
@MainActor
final class YouTubeWebContextService: NSObject, WKNavigationDelegate {
    static let shared = YouTubeWebContextService()

    private let webView: WKWebView
    private let logger = DiagnosticsLogger.api

    private var contextTask: Task<YouTubeContext, Error>?

    struct YouTubeContext: Sendable {
        let apiKey: String
        let clientName: String
        let clientVersion: String
        let visitorData: String?
    }

    override private init() {
        let config = WebKitManager.shared.createWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        self.webView = WKWebView(frame: .zero, configuration: config)
        self.webView.customUserAgent = WebKitManager.userAgent
        super.init()
        self.webView.navigationDelegate = self
    }

    /// Fetches the live YouTube context. Caches it after the first successful fetch.
    func fetchContext() async throws -> YouTubeContext {
        if let task = self.contextTask {
            return try await task.value
        }

        let task = Task { @MainActor in
            try await self.performContextFetch()
        }
        self.contextTask = task

        do {
            return try await task.value
        } catch {
            self.contextTask = nil
            throw error
        }
    }

    /// Invalidates the current context, forcing a refetch on the next request.
    func invalidateContext() {
        self.contextTask = nil
    }

    private func performContextFetch() async throws -> YouTubeContext {
        self.logger.info("Fetching live YouTube web context...")

        // 1. Try URLSession first (fast, reliable, does not block MainActor webView loops)
        if let context = await self.fetchLiveConfigViaSession() {
            return context
        }

        // 2. Fall back to WebView extraction if URLSession failed
        self.logger.info("Falling back to WebView extraction for context...")
        guard let url = URL(string: "https://www.youtube.com") else {
            throw YTMusicError.unknown(message: "Invalid URL")
        }

        self.webView.load(URLRequest(url: url))

        // Wait for ytcfg to become available (poll for up to 10 seconds)
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 10.0 {
            do {
                if try await self.checkIfYtcfgReady() {
                    return try await self.extractContext()
                }
            } catch {
                // Ignore and retry
            }
            try await Task.sleep(for: .milliseconds(500))
        }

        throw YTMusicError.unknown(message: "Unable to load live YouTube configuration")
    }

    private func fetchLiveConfigViaSession() async -> YouTubeContext? {
        guard let url = URL(string: "https://www.youtube.com") else { return nil }
        var request = URLRequest(url: url)
        request.setValue(WebKitManager.userAgent, forHTTPHeaderField: "User-Agent")

        // Share cookies from WebKitManager for correct session
        if let cookieHeader = await WebKitManager.shared.cookieHeader(for: "youtube.com") {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            let apiKeyPattern = "INNERTUBE_API_KEY\":\"([^\"]+)\""
            let keyRegex = try NSRegularExpression(pattern: apiKeyPattern)
            let keyRange = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let keyMatch = keyRegex.firstMatch(in: html, options: [], range: keyRange),
                  let r1 = Range(keyMatch.range(at: 1), in: html) else {
                return nil
            }
            let extractedKey = String(html[r1])

            let versionPattern = "INNERTUBE_CLIENT_VERSION\":\"([^\"]+)\""
            let versionRegex = try NSRegularExpression(pattern: versionPattern)
            let versionRange = NSRange(html.startIndex..<html.endIndex, in: html)

            guard let versionMatch = versionRegex.firstMatch(in: html, options: [], range: versionRange),
                  let r2 = Range(versionMatch.range(at: 1), in: html) else { return nil }
            let extractedVersion = String(html[r2])

            let visitorPattern = "VISITOR_DATA\":\"([^\"]+)\""
            let visitorRegex = try NSRegularExpression(pattern: visitorPattern)
            let visitorRange = NSRange(html.startIndex..<html.endIndex, in: html)
            var visitorData: String?
            if let visitorMatch = visitorRegex.firstMatch(in: html, options: [], range: visitorRange),
               let r3 = Range(visitorMatch.range(at: 1), in: html) {
                visitorData = String(html[r3])
            }

            self.logger.info("Successfully extracted live YouTube config via URLSession (Client: WEB v\(extractedVersion))")

            return YouTubeContext(
                apiKey: extractedKey,
                clientName: "WEB",
                clientVersion: extractedVersion,
                visitorData: visitorData
            )
        } catch {
            self.logger.warning("Failed to fetch live YouTube config via URLSession: \(error.localizedDescription)")
            return nil
        }
    }

    private func checkIfYtcfgReady() async throws -> Bool {
        let result = try await self.webView.evaluateJavaScript("typeof ytcfg !== 'undefined' && ytcfg.get('INNERTUBE_API_KEY') !== undefined")
        return (result as? Bool) == true
    }

    private func extractContext() async throws -> YouTubeContext {
        let script = """
        (function() {
            return {
                apiKey: ytcfg.get('INNERTUBE_API_KEY'),
                clientName: ytcfg.get('INNERTUBE_CLIENT_NAME')?.toString() || 'WEB',
                clientVersion: ytcfg.get('INNERTUBE_CLIENT_VERSION'),
                visitorData: ytcfg.get('VISITOR_DATA') || ''
            };
        })();
        """

        guard let result = try await self.webView.evaluateJavaScript(script) as? [String: Any],
              let apiKey = result["apiKey"] as? String,
              let clientVersion = result["clientVersion"] as? String else {
            throw YTMusicError.unknown(message: "Failed to extract ytcfg values")
        }

        let clientName = result["clientName"] as? String ?? "WEB"
        let visitorData = result["visitorData"] as? String

        self.logger.info("Successfully extracted YouTube context (Client: \(clientName) v\(clientVersion))")

        return YouTubeContext(
            apiKey: apiKey,
            clientName: clientName,
            clientVersion: clientVersion,
            visitorData: visitorData
        )
    }

    func loadInitialData(for path: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://www.youtube.com\(path)") else {
            throw YTMusicError.unknown(message: "Invalid URL")
        }

        self.logger.info("Fetching ytInitialData for \(path)...")

        // Create an isolated WebView to avoid stomping on the shared context webView or other concurrent requests
        let config = WebKitManager.shared.createWebViewConfiguration()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        let localWebView = WKWebView(frame: .zero, configuration: config)
        localWebView.customUserAgent = WebKitManager.userAgent

        var req = URLRequest(url: url)
        if let cookieHeader = await WebKitManager.shared.cookieHeader(for: "youtube.com") {
            req.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        localWebView.load(req)

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < 15.0 {
            do {
                let ready = try await localWebView.evaluateJavaScript("typeof ytInitialData !== 'undefined'") as? Bool ?? false
                if ready {
                    let jsonString = try await localWebView.evaluateJavaScript("JSON.stringify(ytInitialData)") as? String
                    if let data = jsonString?.data(using: .utf8),
                       let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        return json
                    }
                }
            } catch {
                // Ignore and retry
            }
            try await Task.sleep(for: .seconds(0.5))
        }

        throw YTMusicError.unknown(message: "Timeout waiting for ytInitialData on \(path)")
    }
}

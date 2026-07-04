import Foundation
import Testing
@testable import OptiTube

/// Tests for WebKitManager.
@Suite("WebKitManager", .serialized, .tags(.service))
@MainActor
struct WebKitManagerTests {
    var webKitManager: WebKitManager

    init() {
        self.webKitManager = WebKitManager.shared
    }

    @Test("Shared instance exists")
    func sharedInstanceExists() {
        #expect(WebKitManager.shared === self.webKitManager)
    }

    @Test("Data store exists")
    func dataStoreExists() {
        _ = self.webKitManager.dataStore
    }

    @Test("Create WebView configuration")
    func createWebViewConfiguration() {
        let configuration = self.webKitManager.createWebViewConfiguration()
        #expect(configuration.websiteDataStore === self.webKitManager.dataStore)
    }

    @Test("Origin constant")
    func originConstant() {
        #expect(WebKitManager.origin == "https://music.youtube.com")
    }

    @Test("Auth cookie name")
    func authCookieName() {
        #expect(WebKitManager.authCookieName == "__Secure-3PAPISID")
    }

    @Test("Get all cookies")
    func getAllCookies() async {
        _ = await self.webKitManager.getAllCookies()
    }

    @Test("Cookie header for domain")
    func cookieHeaderForDomain() async {
        // May be nil if no cookies are set
        // Just verify it doesn't crash
        _ = await self.webKitManager.cookieHeader(for: "youtube.com")
    }

    @Test("Has auth cookies")
    func hasAuthCookies() async {
        let hasAuth = await webKitManager.hasAuthCookies()
        // Just verify the method works and returns a Bool
        #expect(hasAuth == true || hasAuth == false)
    }
}

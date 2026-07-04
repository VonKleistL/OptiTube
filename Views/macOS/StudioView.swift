// StudioView.swift
// OptiTube
//
// Hosts the full YouTube Studio web app inside the app, themed to match
// the OptiTube glass/dark backgrounds like the YouTube watch surface.
// Navigation uses Studio's own drawer — no duplicated native controls.

import AppKit
import SwiftUI
import WebKit

// MARK: - StudioWebView

/// Manages the single persistent WebView hosting studio.youtube.com.
/// Mirrors `YouTubeWatchWebView`: created once, reparented as needed,
/// transparent so the app theme (glass/nebula/darkness) shows through.
@MainActor
final class StudioWebView {
    static let shared = StudioWebView()

    private(set) var webView: WKWebView?
    private var coordinator: Coordinator?
    private let logger = DiagnosticsLogger.ui

    private init() {}

    func getWebView(webKitManager: WebKitManager) -> WKWebView {
        if let existing = webView {
            return existing
        }

        self.logger.info("Creating YouTube Studio WebView")

        let coordinator = Coordinator()
        self.coordinator = coordinator

        let configuration = webKitManager.createWebViewConfiguration()
        let style = WKUserScript(
            source: Self.studioStyleScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(style)
        let backdropFix = WKUserScript(
            source: Self.dismissBackdropScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(backdropFix)

        // Desktop-sized initial frame: a zero-sized WebView makes Studio boot
        // in its narrow/responsive layout, which opens the navigation drawer
        // as a modal with a dark scrim over the whole page.
        let newWebView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 1280, height: 800),
            configuration: configuration
        )
        newWebView.navigationDelegate = coordinator
        newWebView.uiDelegate = coordinator
        newWebView.customUserAgent = WebKitManager.userAgent
        newWebView.underPageBackgroundColor = .clear
        // Same as the watch surface: let the app theme show through.
        newWebView.setValue(false, forKey: "drawsBackground")

        #if DEBUG
            newWebView.isInspectable = true
        #endif

        self.webView = newWebView
        newWebView.load(URLRequest(url: URL(string: "https://studio.youtube.com/")!))
        return newWebView
    }

    func ensureInHierarchy(container: NSView) {
        guard let webView, webView.superview !== container else { return }
        webView.removeFromSuperview()
        container.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            createWebViewWith _: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures _: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url else { return nil }
            // Google/YouTube auth flows must stay inside the app's WebKit
            // session (its cookies live here) — an external browser can
            // never sign this WebView in.
            let host = url.host ?? ""
            if host.hasSuffix("google.com") || host.hasSuffix("youtube.com") {
                webView.load(navigationAction.request)
            } else {
                // Genuinely external links (e.g. sponsor sites) open in browser.
                NSWorkspace.shared.open(url)
            }
            return nil
        }
    }

    /// Makes Studio's page-level backgrounds transparent so the app theme
    /// shows through, and hides Studio's top bar to match the YouTube surface.
    static var studioStyleScript: String {
        """
        (function() {
            const style = document.createElement('style');
            style.id = 'optitube-studio-style';
            style.textContent = `
                /* Hide Studio's own top bar to match the YouTube surface. */
                ytcp-header,
                #header.ytcp-app {
                    display: none !important;
                }
                html,
                body,
                ytcp-app,
                #main-container,
                .main-container,
                ytcp-navigation-drawer,
                #main,
                .page {
                    background: transparent !important;
                }
                body::-webkit-scrollbar {
                    display: none;
                }
            `;
            if (document.documentElement) {
                document.documentElement.appendChild(style);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    document.documentElement.appendChild(style);
                });
            }
        })();
        """
    }

    /// Dismisses the stray modal drawer scrim Studio can open right after
    /// load. Only runs for the first few seconds so genuine dialogs
    /// (upload, confirmations) keep their backdrops.
    static var dismissBackdropScript: String {
        """
        (function() {
            var attempts = 0;
            var timer = setInterval(function() {
                attempts += 1;
                try {
                    document.querySelectorAll('tp-yt-iron-overlay-backdrop.opened').forEach(function(backdrop) {
                        backdrop.click();
                    });
                } catch (e) {}
                if (attempts >= 12) { clearInterval(timer); }
            }, 500);
        })();
        """
    }
}

// MARK: - StudioSurfaceView

/// Hosts the persistent Studio WebView inside SwiftUI.
struct StudioSurfaceView: NSViewRepresentable {
    @Environment(WebKitManager.self) private var webKitManager

    func makeNSView(context _: Context) -> YouTubeWatchContainerView {
        let container = YouTubeWatchContainerView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        return container
    }

    func updateNSView(_ nsView: YouTubeWatchContainerView, context _: Context) {
        _ = StudioWebView.shared.getWebView(webKitManager: self.webKitManager)
        StudioWebView.shared.ensureInHierarchy(container: nsView)
    }
}

// MARK: - StudioContentView

/// Detail column for Studio mode — the full Studio web app with its own navigation.
@available(macOS 15.0, *)
struct StudioContentView: View {
    var body: some View {
        StudioSurfaceView()
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StudioSidebar

/// Minimal sidebar for Studio mode: Studio's own drawer handles navigation,
/// so this only carries the source toggle and profile.
@available(macOS 15.0, *)
struct StudioSidebar: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Divider()
                .opacity(0.3)

            SourceToggleView()
                .padding(.horizontal, 12)
                .padding(.top, 8)

            SidebarProfileView()
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
    }
}

import SwiftUI
import WebKit

// MARK: - SingletonPlayerWebView Video Mode Extension

extension SingletonPlayerWebView {
    /// Updates WebView size based on display mode.
    func updateDisplayMode(_ mode: DisplayMode) {
        guard let webView else { return }
        self.displayMode = mode

        switch mode {
        case .hidden:
            // WebView stays in hierarchy but tiny
            webView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            self.removeVideoModeCSS()
        case .miniPlayer:
            webView.frame = CGRect(x: 0, y: 0, width: 160, height: 90)
            self.removeVideoModeCSS()
        case .video:
            // Immediately inject blackout CSS to hide web UI while we prepare video
            self.injectBlackoutCSS()
            // Full size - parent container determines size
            // Defer injection until container has valid bounds (SwiftUI layout)
            self.waitForValidBoundsAndInject()
        }
    }

    /// Injects a temporary blackout overlay to hide the web UI during video mode setup.
    func injectBlackoutCSS() {
        guard let webView else { return }

        let script = """
            (function() {
                // Create blackout overlay if it doesn't exist
                if (!document.getElementById('optitube-blackout')) {
                    const blackout = document.createElement('div');
                    blackout.id = 'optitube-blackout';
                    blackout.style.cssText = `
                        position: fixed !important;
                        top: 0 !important;
                        left: 0 !important;
                        width: 100vw !important;
                        height: 100vh !important;
                        background: #000 !important;
                        z-index: 2147483646 !important;
                    `;
                    document.body.appendChild(blackout);
                }
            })();
        """
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                DiagnosticsLogger.player.error("Failed to inject blackout CSS: \(error.localizedDescription)")
            }
        }
    }

    /// Waits for the WebView's superview to have valid (non-zero) bounds, then injects CSS.
    func waitForValidBoundsAndInject(attempts: Int = 0) {
        guard let webView else { return }

        let maxAttempts = 20 // 2 seconds max (20 * 100ms)
        if let superview = webView.superview, superview.bounds.width > 0, superview.bounds.height > 0 {
            webView.frame = superview.bounds
            webView.autoresizingMask = [.width, .height]
            self.injectVideoModeCSS()
        } else if attempts < maxAttempts {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                self?.waitForValidBoundsAndInject(attempts: attempts + 1)
            }
        } else {
            // Fall back to current bounds anyway
            if let superview = webView.superview {
                webView.frame = superview.bounds
                webView.autoresizingMask = [.width, .height]
            }
            self.injectVideoModeCSS()
        }
    }

    /// Injects CSS to hide YouTube Music UI and show only the video.
    /// Called when entering video mode or when page reloads while in video mode.
    func injectVideoModeCSS() {
        guard let webView else { return }

        // First, let's debug what's in the DOM
        let debugScript = """
            (function() {
                const video = document.querySelector('video');
                const videoInfo = video ? {
                    src: video.src ? video.src.substring(0, 100) : 'none',
                    width: video.videoWidth,
                    height: video.videoHeight,
                    paused: video.paused,
                    display: getComputedStyle(video).display,
                    visibility: getComputedStyle(video).visibility
                } : 'no video element';

                const tabs = document.querySelectorAll('tp-yt-paper-tab');
                const tabTexts = Array.from(tabs).map(t => t.textContent.trim());

                const playerPage = document.querySelector('ytmusic-player-page');
                const moviePlayer = document.querySelector('#movie_player');
                const html5Player = document.querySelector('.html5-video-player');

                return {
                    videoInfo: videoInfo,
                    tabTexts: tabTexts,
                    hasPlayerPage: !!playerPage,
                    hasMoviePlayer: !!moviePlayer,
                    hasHtml5Player: !!html5Player,
                    url: window.location.href
                };
            })();
        """

        webView.evaluateJavaScript(debugScript) { [weak self] _, _ in
            // Now click the Video tab
            self?.clickVideoTabAndInjectCSS()
        }
    }

    /// Clicks the Video tab and then injects CSS.
    func clickVideoTabAndInjectCSS() {
        guard let webView else { return }

        // The Track/Video toggle is different from the tabs
        // It appears as a segmented control near the top of the player page
        let clickVideoTabScript = """
            (function() {
                // Method 1: Look for the Track/Video toggle buttons
                // These are typically in a toggle group with "Track" and "Video" labels
                const toggleButtons = document.querySelectorAll('tp-yt-paper-button, button, [role="button"]');
                for (const btn of toggleButtons) {
                    const text = (btn.textContent || btn.innerText || '').trim().toLowerCase();
                    if (text === 'video') {
                        btn.click();
                        console.log('[OptiTube] Clicked Video toggle button');
                        return { clicked: true, method: 'toggleButton', text: text };
                    }
                }

                // Method 2: Look for ytmusic-player-page and find the toggle there
                const playerPage = document.querySelector('ytmusic-player-page');
                if (playerPage) {
                    // The toggle might be in a specific container
                    const toggleContainer = playerPage.querySelector('.toggle-container, .segment-button-container, [class*="toggle"]');
                    if (toggleContainer) {
                        const buttons = toggleContainer.querySelectorAll('button, [role="button"]');
                        for (const btn of buttons) {
                            const text = (btn.textContent || '').trim().toLowerCase();
                            if (text === 'video') {
                                btn.click();
                                return { clicked: true, method: 'toggleContainer', text: text };
                            }
                        }
                    }
                }

                // Method 3: Find by aria-label or data attributes
                const videoBtn = document.querySelector('[aria-label*="Video" i], [data-value="VIDEO"]');
                if (videoBtn) {
                    videoBtn.click();
                    return { clicked: true, method: 'ariaLabel' };
                }

                // Method 4: Look in the header area for Track/Video chips
                const chips = document.querySelectorAll('yt-chip-cloud-chip-renderer, ytmusic-chip-renderer, .chip');
                for (const chip of chips) {
                    const text = (chip.textContent || '').trim().toLowerCase();
                    if (text === 'video') {
                        chip.click();
                        return { clicked: true, method: 'chip', text: text };
                    }
                }

                return { clicked: false, message: 'Video toggle not found' };
            })();
        """

        webView.evaluateJavaScript(clickVideoTabScript) { [weak self] result, _ in
            // Log if Video tab wasn't found (YouTube UI may have changed)
            if let resultDict = result as? [String: Any],
               let clicked = resultDict["clicked"] as? Bool,
               !clicked
            {
                self?.logger.warning("Video tab not found - YouTube UI may have changed")
            }

            // Wait a moment for the video mode to activate, then inject CSS
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                self?.injectVideoModeStyles()
            }
        }
    }

    /// Actually injects the CSS styles for video mode.
    func injectVideoModeStyles() {
        guard let webView else { return }

        let script = """
        (function() {
            'use strict';

            // 1. Hide everything else in the body to prevent "messy" backgrounds or leaks
            let style = document.getElementById('optitube-video-hide-all');
            if (!style) {
                style = document.createElement('style');
                style.id = 'optitube-video-hide-all';
                document.head.appendChild(style);
            }
            style.textContent = `
                body > *:not(#optitube-video-container):not(#optitube-blackout):not(script):not(style) {
                    display: none !important;
                }
                body {
                    background: #000 !important;
                    overflow: hidden !important;
                    width: 100vw !important;
                    height: 100vh !important;
                    margin: 0 !important;
                    padding: 0 !important;
                }
                html {
                    overflow: hidden !important;
                }
            `;

            // 2. Remove existing OptiTube video container if present
            const existingContainer = document.getElementById('optitube-video-container');
            if (existingContainer) {
                const video = existingContainer.querySelector('video');
                if (video && video.__optitubeOriginalParent) {
                    video.__optitubeOriginalParent.appendChild(video);
                }
                existingContainer.remove();
            }

            // 3. Find the video element
            const video = document.querySelector('video');
            if (!video) {
                console.log('[OptiTube] No video element found');
                return { success: false, error: 'No video element' };
            }

            // Store original parent for restoration later
            if (!video.__optitubeOriginalParent) {
                video.__optitubeOriginalParent = video.parentElement;
            }

            // 4. Create a fullscreen container for the video using viewport units
            //    so it auto-resizes with the window/WebView
            const container = document.createElement('div');
            container.id = 'optitube-video-container';
            container.style.cssText = `
                position: fixed !important;
                top: 0 !important;
                left: 0 !important;
                width: 100vw !important;
                height: 100vh !important;
                background: #000 !important;
                z-index: 2147483647 !important;
                display: flex !important;
                align-items: center !important;
                justify-content: center !important;
            `;

            // Style the video element to fill our container perfectly
            video.style.cssText = `
                width: 100% !important;
                height: 100% !important;
                max-width: 100% !important;
                max-height: 100% !important;
                object-fit: contain !important;
                background: #000 !important;
                border: none !important;
                pointer-events: none !important;
            `;
            video.controls = false;

            // 5. Assemble and inject
            container.appendChild(video);
            document.body.appendChild(container);

            // Remove blackout now that video container is in place
            const blackout = document.getElementById('optitube-blackout');
            if (blackout) blackout.remove();

            // Restore volume
            if (typeof window.__optitubeTargetVolume === 'number') {
                video.volume = window.__optitubeTargetVolume;
            }

            return {
                success: true,
                videoWidth: video.videoWidth,
                videoHeight: video.videoHeight
            };
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                DiagnosticsLogger.player.error("Failed to inject video mode styles: \(error.localizedDescription)")
                return
            }
            if let dict = result as? [String: Any],
               let success = dict["success"] as? Bool,
               !success
            {
                DiagnosticsLogger.player.warning("Video mode CSS injection reported failure: \(dict)")
            }
        }
    }

    /// Removes the video container and restores the video to its original location.
    func removeVideoModeCSS() {
        guard let webView else { return }

        let script = """
            (function() {
                // Remove blackout overlay
                const blackout = document.getElementById('optitube-blackout');
                if (blackout) blackout.remove();

                // Remove hide-all styles
                const hideAllStyle = document.getElementById('optitube-video-hide-all');
                if (hideAllStyle) hideAllStyle.remove();

                // Remove old CSS-based style if present
                const style = document.getElementById('optitube-video-mode-style');
                if (style) style.remove();

                // Remove video style
                const videoStyle = document.getElementById('optitube-video-style');
                if (videoStyle) videoStyle.remove();

                // Remove video container and restore video to original parent
                const container = document.getElementById('optitube-video-container');
                if (container) {
                    const video = container.querySelector('video');
                    if (video && video.__optitubeOriginalParent) {
                        // Restore video styles and remove controls
                        video.style.cssText = '';
                        video.controls = false;
                        // Move back to original parent
                        video.__optitubeOriginalParent.appendChild(video);
                        delete video.__optitubeOriginalParent;
                    }
                    container.remove();
                    console.log('[OptiTube] Video restored to original location');
                }
            })();
        """

        webView.evaluateJavaScript(script) { _, error in
            if let error {
                DiagnosticsLogger.player.error("Failed to remove video mode CSS: \(error.localizedDescription)")
            }
        }
    }

    /// Re-injects video mode after resize or other layout changes.
    /// With viewport-unit CSS, the container auto-resizes, but we still
    /// need to ensure the WebView frame matches its superview.
    func refreshVideoModeCSS() {
        guard self.displayMode == .video, let webView else { return }

        // Sync WebView frame with its container
        if let superview = webView.superview, superview.bounds.width > 0, superview.bounds.height > 0 {
            webView.frame = superview.bounds
        }

        // The CSS uses 100vw/100vh so the container auto-resizes.
        // Just verify the container is still in place.
        let verifyScript = """
        (function() {
            const container = document.getElementById('optitube-video-container');
            if (!container) return { success: false };

            // Ensure container uses viewport units (in case of legacy state)
            container.style.width = '100vw';
            container.style.height = '100vh';

            return { success: true, width: window.innerWidth, height: window.innerHeight };
        })();
        """
        webView.evaluateJavaScript(verifyScript) { result, error in
            if let error {
                DiagnosticsLogger.player.error("Failed to refresh video mode CSS: \(error.localizedDescription)")
                return
            }
            if let dict = result as? [String: Any],
               let success = dict["success"] as? Bool,
               !success
            {
                DiagnosticsLogger.player.warning("Video mode CSS verify reported failure")
            }
        }
    }
}


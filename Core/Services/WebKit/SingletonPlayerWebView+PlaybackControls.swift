import WebKit

// MARK: - SingletonPlayerWebView Playback Controls Extension

extension SingletonPlayerWebView {
    /// Toggle play/pause.
    func playPause() {
        guard let webView else { return }

        let script = """
            (function() {
                const playBtn = document.querySelector('.play-pause-button.ytmusic-player-bar');
                if (playBtn) { playBtn.click(); return 'clicked'; }
                const video = document.querySelector('video');
                if (video) {
                    if (video.paused) { video.play(); return 'played'; }
                    else { video.pause(); return 'paused'; }
                }
                return 'no-element';
            })();
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.logger.error("playPause error: \(error.localizedDescription)")
            }
        }
    }

    /// Play (resume).
    func play() {
        guard let webView else { return }

        let script = """
            (function() {
                const video = document.querySelector('video');
                if (video && video.paused) { video.play(); return 'played'; }
                return 'already-playing';
            })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Pause.
    func pause() {
        guard let webView else { return }

        let script = """
            (function() {
                const video = document.querySelector('video');
                if (video && !video.paused) { video.pause(); return 'paused'; }
                return 'already-paused';
            })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Skip to next track.
    func next() {
        guard let webView else { return }

        let script = """
            (function() {
                const nextBtn = document.querySelector('.next-button.ytmusic-player-bar');
                if (nextBtn) { nextBtn.click(); return 'clicked'; }
                return 'no-button';
            })();
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.logger.error("next error: \(error.localizedDescription)")
            }
        }
    }

    /// Go to previous track.
    func previous() {
        guard let webView else { return }

        let script = """
            (function() {
                const prevBtn = document.querySelector('.previous-button.ytmusic-player-bar');
                if (prevBtn) { prevBtn.click(); return 'clicked'; }
                return 'no-button';
            })();
        """
        webView.evaluateJavaScript(script) { [weak self] _, error in
            if let error {
                self?.logger.error("previous error: \(error.localizedDescription)")
            }
        }
    }

    /// Seek to a specific time in seconds.
    func seek(to time: Double) {
        guard let webView else { return }

        let script = """
            (function() {
                const video = document.querySelector('video');
                if (video) { video.currentTime = \(time); return 'seeked'; }
                return 'no-video';
            })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Seeks to the start and resumes playback without forcing full navigation.
    func restartInPlaceFromBeginning() {
        self.seek(to: 0)
        self.play()
    }

    /// Set volume (0.0 - 1.0).
    func setVolume(_ volume: Double) {
        guard let webView else { return }
        let clampedVolume = max(0, min(1, volume))

        // Update target volume and set video volume directly
        // Also try to set YouTube's internal player volume via their API
        let script = """
            (function() {
                window.__optitubeTargetVolume = \(clampedVolume);
                const video = document.querySelector('video');
                let result = [];

                if (video) {
                    // Set flag to prevent volumechange listener from reverting
                    window.__optitubeIsSettingVolume = true;
                    video.volume = \(clampedVolume);
                    result.push('video.volume=' + video.volume);
                    setTimeout(() => { window.__optitubeIsSettingVolume = false; }, 50);
                } else {
                    result.push('no-video');
                }

                // Also try YouTube Music's internal player API
                const player = document.querySelector('ytmusic-player');
                if (player && player.playerApi) {
                    const ytVolume = Math.round(\(clampedVolume) * 100);
                    player.playerApi.setVolume(ytVolume);
                    result.push('ytapi.setVolume=' + ytVolume);
                }

                // Try movie_player API as fallback
                const moviePlayer = document.getElementById('movie_player');
                if (moviePlayer && moviePlayer.setVolume) {
                    const ytVolume = Math.round(\(clampedVolume) * 100);
                    moviePlayer.setVolume(ytVolume);
                    result.push('movie_player.setVolume=' + ytVolume);
                }

                return result.join(', ');
            })();
        """
        webView.evaluateJavaScript(script) { _, error in
            if let error {
                self.logger.error("setVolume error: \(error.localizedDescription)")
            }
        }
    }

    /// Fades the volume to a target level over a specified duration.
    func fadeVolume(to targetVolume: Double, durationMs: Int, completion: (() -> Void)? = nil) {
        guard let webView else {
            completion?()
            return
        }
        
        let clampedVolume = max(0, min(1, targetVolume))
        let script = """
            (function() {
                const video = document.querySelector('video');
                if (!video) return 'no-video';
                
                const startVolume = video.volume;
                const delta = \(clampedVolume) - startVolume;
                const steps = 10;
                const intervalTime = \(durationMs) / steps;
                let currentStep = 0;
                
                window.__optitubeIsSettingVolume = true;
                
                const interval = setInterval(() => {
                    currentStep++;
                    video.volume = startVolume + (delta * (currentStep / steps));
                    if (currentStep >= steps) {
                        clearInterval(interval);
                        window.__optitubeIsSettingVolume = false;
                    }
                }, intervalTime);
                
                return 'fade-started';
            })();
        """
        
        webView.evaluateJavaScript(script) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(durationMs)) {
                completion?()
            }
        }
    }

    /// Shows the AirPlay picker by triggering it via JavaScript.
    func showAirPlayPicker() {
        guard let webView else { return }

        // WebKit doesn't expose direct AirPlay controls, but we can try to
        // trigger the video element's remote playback API
        let script = """
            (function() {
                const video = document.querySelector('video');
                if (video && video.remote && video.remote.prompt) {
                    video.remote.prompt().catch(e => console.log('AirPlay prompt error:', e));
                    return 'prompted';
                }
                return 'no-remote-api';
            })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error {
                self?.logger.error("showAirPlayPicker error: \(error.localizedDescription)")
            } else {
                self?.logger.debug("showAirPlayPicker: \(String(describing: result))")
            }
        }
    }
}

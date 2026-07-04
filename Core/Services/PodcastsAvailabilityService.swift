import Foundation
import Observation

// MARK: - PodcastsAvailabilityService

/// Tracks whether the YouTube Music Podcasts discovery surface is
/// available for the current session. YouTube does not offer the surface
/// in every region, and `FEmusic_podcasts` returns HTTP 404 in those
/// regions. The sidebar consults this service to hide the row when the
/// endpoint is known to be unavailable.
///
/// State is in-memory only — no persistence. Each app launch re-probes
/// from scratch so a region change (e.g. enabling a VPN before
/// relaunching) is reflected without sign-out/in. The owning view
/// defers rendering main content until `didResolveFirstProbe` flips, so
/// the user never sees the Podcasts row appear-then-disappear.
@MainActor
@Observable
final class PodcastsAvailabilityService {
    enum Availability: Equatable {
        case unknown
        case available
        case unavailable
    }

    /// Current state. `Sidebar` reads this to decide whether to render
    /// the Podcasts row (renders on `.unknown` and `.available`, hides on
    /// `.unavailable`).
    private(set) var availability: Availability = .unknown

    /// `true` once the first probe of the session resolves (success,
    /// 404, transient error) or the timeout fires. `MainWindow` uses
    /// this as a UI gate — main content renders only after this flips,
    /// so the sidebar paints with the correct state on first frame.
    private(set) var didResolveFirstProbe: Bool = false

    /// Maximum time the gate waits for the first probe before failing
    /// open and letting the sidebar render with `availability` still
    /// `.unknown` (which displays the same as `.available`). If the
    /// probe later returns 404, the lazy path
    /// (`PodcastsViewModel.load`) demotes the state.
    static let firstProbeGateTimeout: Duration = .seconds(2)

    private var accountScope: AccountScope = .unconfigured
    private var generation = 0

    init() {}

    // MARK: - Account scope

    /// Records the currently-active account without changing the visible
    /// availability state. This invalidates in-flight probes from the
    /// previous account so a late completion cannot mutate the new
    /// account's state.
    func activateAccount(_ accountId: String?) {
        let scope = AccountScope.account(Self.normalizedAccountId(accountId))
        guard self.accountScope != scope else { return }

        self.accountScope = scope
        self.generation += 1
    }

    // MARK: - Probing

    /// Runs the first probe of the session and resolves the UI gate.
    /// Returns when the probe completes OR the timeout fires —
    /// whichever happens first. The probe always runs to completion in
    /// the background regardless of the timeout, so a slow-but-definite
    /// 404 still demotes the tab when it lands.
    func probeForFirstResolution(
        for accountId: String?,
        using client: YTMusicClient,
        timeout: Duration = firstProbeGateTimeout
    ) async {
        self.activateAccount(accountId)

        let probeTask = Task { [weak self] in
            _ = await self?.probe(for: accountId, using: client)
        }

        let latch = ResumeLatch()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task { @MainActor in
                try? await Task.sleep(for: timeout)
                latch.tryResume(continuation)
            }
            Task { @MainActor in
                _ = await probeTask.value
                latch.tryResume(continuation)
            }
        }

        if Task.isCancelled {
            probeTask.cancel()
            return
        }
        self.resolveFirstProbeGateIfActive(for: accountId)
    }

    /// Calls `client.getPodcasts()` and updates `availability` based on
    /// the result. Used by `probeForFirstResolution` and by the account
    /// switch flow.
    @discardableResult
    func probe(
        for accountId: String?,
        using client: YTMusicClient
    ) async -> Availability {
        let token = self.beginProbe(for: accountId)
        let label = token.accountId
        DiagnosticsLogger.api.info("Probing podcasts availability for account=\(label)")

        do {
            let sections = try await client.getPodcasts()
            guard self.shouldApplyProbeResult(token, outcome: "success") else {
                return self.availability
            }

            if sections.isEmpty {
                DiagnosticsLogger.api.info("Probe returned 0 sections; leaving availability=\(String(describing: self.availability))")
                self.didResolveFirstProbe = true
                return self.availability
            }
            self.availability = .available
            self.didResolveFirstProbe = true
            return .available
        } catch let YTMusicError.apiError(_, code) where code == 404 {
            guard self.shouldApplyProbeResult(token, outcome: "HTTP 404") else {
                return self.availability
            }

            DiagnosticsLogger.api.info("Probe returned HTTP 404; podcasts unavailable for account=\(label)")
            self.availability = .unavailable
            self.didResolveFirstProbe = true
            return .unavailable
        } catch is CancellationError {
            DiagnosticsLogger.api.debug("Probe cancelled for account=\(label)")
            return self.availability
        } catch {
            guard self.shouldApplyProbeResult(token, outcome: "inconclusive") else {
                return self.availability
            }

            DiagnosticsLogger.api.debug("Probe inconclusive for account=\(label): \(error.localizedDescription)")
            self.didResolveFirstProbe = true
            return self.availability
        }
    }

    // MARK: - Lazy signals (from PodcastsViewModel)

    /// Marks podcasts as unavailable based on a user-initiated load
    /// that hit 404 or returned an empty payload.
    func markUnavailable(for accountId: String?) {
        guard self.shouldApplyLazySignal(for: accountId, outcome: "unavailable") else { return }

        self.generation += 1
        self.availability = .unavailable
        self.didResolveFirstProbe = true
    }

    /// Marks podcasts as available based on a user-initiated load that
    /// returned a non-empty payload.
    func markAvailable(for accountId: String?) {
        guard self.shouldApplyLazySignal(for: accountId, outcome: "available") else { return }

        self.generation += 1
        self.availability = .available
        self.didResolveFirstProbe = true
    }

    // MARK: - Lifecycle

    /// Resets state so the next sign-in re-gates the UI and re-probes.
    /// Called on logout.
    func reset() {
        self.accountScope = .loggedOut
        self.generation += 1
        self.availability = .unknown
        self.didResolveFirstProbe = false
    }

    private func beginProbe(for accountId: String?) -> ProbeToken {
        self.activateAccount(accountId)
        self.generation += 1
        return ProbeToken(
            accountId: Self.normalizedAccountId(accountId),
            generation: self.generation
        )
    }

    private func shouldApplyProbeResult(
        _ token: ProbeToken,
        outcome: String
    ) -> Bool {
        guard self.accountScope == .account(token.accountId),
              self.generation == token.generation
        else {
            DiagnosticsLogger.api.debug("Ignoring stale podcasts availability probe for account=\(token.accountId), outcome=\(outcome)")
            return false
        }
        return true
    }

    private func shouldApplyLazySignal(for accountId: String?, outcome: String) -> Bool {
        let normalizedAccountId = Self.normalizedAccountId(accountId)
        switch self.accountScope {
        case .unconfigured:
            self.accountScope = .account(normalizedAccountId)
            self.generation += 1
            return true
        case .loggedOut:
            DiagnosticsLogger.api.debug("Ignoring podcasts availability signal while logged out for account=\(normalizedAccountId), outcome=\(outcome)")
            return false
        case let .account(activeAccountId):
            guard activeAccountId == normalizedAccountId else {
                DiagnosticsLogger.api.debug("Ignoring stale podcasts availability signal for account=\(normalizedAccountId), outcome=\(outcome)")
                return false
            }
            return true
        }
    }

    private func resolveFirstProbeGateIfActive(for accountId: String?) {
        let normalizedAccountId = Self.normalizedAccountId(accountId)
        guard self.accountScope == .account(normalizedAccountId) else {
            DiagnosticsLogger.api.debug("Ignoring stale first podcasts probe gate for account=\(normalizedAccountId)")
            return
        }
        self.didResolveFirstProbe = true
    }

    private static func normalizedAccountId(_ accountId: String?) -> String {
        accountId ?? "primary"
    }
}

private extension PodcastsAvailabilityService {
    enum AccountScope: Equatable {
        case unconfigured
        case loggedOut
        case account(String)
    }

    struct ProbeToken: Equatable {
        let accountId: String
        let generation: Int
    }
}

// MARK: - ResumeLatch

/// Single-resume gate used by `probeForFirstResolution` to race two
/// `@MainActor`-isolated tasks (probe completion vs timeout).
@MainActor
private final class ResumeLatch {
    private var resumed = false

    func tryResume(_ continuation: CheckedContinuation<Void, Never>) {
        guard !self.resumed else { return }
        self.resumed = true
        continuation.resume()
    }
}

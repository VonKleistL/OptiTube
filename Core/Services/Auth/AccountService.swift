// AccountService.swift
// OptiTube
//
// Manages account state and brand account switching.

import Foundation
import Observation

/// Manages account state and switching between primary and brand accounts.
@Observable
@MainActor
final class AccountService {
    // MARK: - Dependencies

    private let ytMusicClient: any YTMusicClientProtocol
    private let authService: AuthService
    private let webKitManager: (any WebKitManagerProtocol)?

    // MARK: - Published State

    /// All available accounts (primary + brand accounts).
    private(set) var accounts: [UserAccount] = []

    /// Currently selected/active account.
    private(set) var currentAccount: UserAccount?

    /// The account whose playback session identity has been *verified*
    private(set) var verifiedAccountId: String?

    /// Bumped each time a session identity is verified.
    private(set) var verifiedIdentitySequence: Int = 0

    /// Whether an account operation is in progress.
    private(set) var isLoading: Bool = false

    /// Last error encountered, for toast display.
    private(set) var lastError: Error?

    /// Whether the last error was from fetching accounts (vs switching).
    private(set) var lastErrorWasFetch: Bool = false

    /// Incremented each time an error occurs, to trigger toast re-display.
    private(set) var errorSequence: Int = 0

    // MARK: - Computed Properties

    /// Returns `true` if the user has multiple accounts (brand accounts available).
    var hasBrandAccounts: Bool {
        self.accounts.count > 1
    }

    /// The brand ID of the currently selected account, if any.
    var currentBrandId: String? {
        self.currentAccount?.brandId
    }

    // MARK: - Private

    private let logger = DiagnosticsLogger.auth
    private let selectedBrandIdKey = "selectedBrandId"

    private var sessionPinTask: Task<Void, Never>?
    private var sessionPinGeneration = 0
    private var activeSwitchNavigation: Task<Void, Error>?
    private var switchGeneration: Int = 0
    private var manualSwitchInFlightCount = 0
    private var accountDataGeneration = 0

    private func markIdentityVerified(_ accountId: String?) {
        self.verifiedAccountId = accountId
        self.verifiedIdentitySequence &+= 1
    }

    private func runTrackedSessionSwitch(
        with webKitManager: any WebKitManagerProtocol,
        to signinURL: URL,
        expectedBrandId: String?
    ) async throws {
        let navigation = Task { @MainActor in
            try await webKitManager.switchSessionIdentity(
                to: signinURL,
                expectedBrandId: expectedBrandId
            )
        }
        self.activeSwitchNavigation = navigation
        defer {
            if self.activeSwitchNavigation == navigation {
                self.activeSwitchNavigation = nil
            }
        }
        try await navigation.value
    }

    // MARK: - Initialization

    /// Creates an AccountService with the required dependencies.
    init(
        ytMusicClient: any YTMusicClientProtocol,
        authService: AuthService,
        webKitManager: (any WebKitManagerProtocol)? = nil
    ) {
        self.ytMusicClient = ytMusicClient
        self.authService = authService
        self.webKitManager = webKitManager
        
        // Connect brand ID provider to client
        if let client = ytMusicClient as? YTMusicClient {
            client.brandIdProvider = { [weak self] in
                self?.currentAccount?.brandId
            }
        }
    }

    // MARK: - Public Methods

    /// Fetches the list of available accounts from the API.
    func fetchAccounts() async {
        guard self.authService.state.isLoggedIn else {
            self.logger.debug("AccountService: Skipping fetch - not logged in")
            return
        }

        self.logger.info("AccountService: Fetching accounts list")
        self.isLoading = true
        let fetchGeneration = self.accountDataGeneration

        defer {
            self.isLoading = false
        }

        do {
            let response = try await self.ytMusicClient.fetchAccountsList()
            guard fetchGeneration == self.accountDataGeneration,
                  self.authService.state.isLoggedIn
            else {
                self.logger.info("AccountService: Ignoring stale account fetch after auth/account state changed")
                return
            }
            guard !response.accounts.isEmpty else {
                self.logger.warning("AccountService: Authenticated account list was empty; requiring re-authentication")
                self.authService.sessionExpired()
                throw YTMusicError.authExpired
            }
            self.accounts = response.accounts

            // Restore previously selected account if stored
            if let savedBrandId = UserDefaults.standard.string(forKey: self.selectedBrandIdKey) {
                self.logger.debug("AccountService: Found saved brand ID: \(savedBrandId)")

                // Find the account with the saved brand ID
                if let savedAccount = self.accounts.first(where: { $0.id == savedBrandId }) {
                    self.currentAccount = savedAccount
                    self.logger.info("AccountService: Restored previous account: \(savedAccount.name)")
                } else {
                    // Saved account no longer available, use API-selected
                    self.currentAccount = response.selectedAccount ?? self.accounts.first
                    self.logger.debug("AccountService: Saved account not found, using API-selected")
                }
            } else {
                // Default to the currently selected account from API response
                self.currentAccount = response.selectedAccount ?? self.accounts.first
                self.logger.debug("AccountService: Using API-selected account")
            }

            let currentLabel = self.currentAccount?.brandId ?? "primary"
            self.logger.info("AccountService: Fetched \(self.accounts.count) accounts, current: \(self.currentAccount?.name ?? "none") (brandId=\(currentLabel))")

            if self.verifiedAccountId != self.currentAccount?.id {
                self.scheduleRestoredSessionPin()
            }
        } catch {
            self.logger.error("AccountService: Failed to fetch accounts: \(error.localizedDescription)")
            self.lastError = error
            self.lastErrorWasFetch = true
            self.errorSequence += 1
        }
    }

    private func scheduleRestoredSessionPin() {
        let priorPinTask = self.sessionPinTask
        let priorNavigation = self.activeSwitchNavigation
        priorPinTask?.cancel()
        self.sessionPinTask = nil

        guard self.manualSwitchInFlightCount == 0 else {
            self.logger.info("AccountService: Skipping restored session pin while a manual switch is in flight")
            self.sessionPinGeneration &+= 1
            return
        }
        if let priorNavigation {
            self.logger.info("AccountService: Cancelling previous restored session navigation before scheduling a new pin")
            priorNavigation.cancel()
            self.activeSwitchNavigation = nil
        }

        guard !UITestConfig.isUITestMode,
              let webKitManager = self.webKitManager,
              let account = self.currentAccount
        else {
            return
        }
        guard let signinURL = account.signinURL else {
            guard account.brandId != nil else {
                if self.verifiedAccountId != account.id {
                    self.markIdentityVerified(nil)
                }
                return
            }
            self.sessionPinGeneration &+= 1
            let pinGeneration = self.sessionPinGeneration
            let error = SessionSwitchError.identityNotApplied(expectedBrandId: account.brandId)
            self.sessionPinTask = Task { [weak self, priorPinTask, priorNavigation] in
                defer {
                    if let self, self.sessionPinGeneration == pinGeneration {
                        self.sessionPinTask = nil
                    }
                }
                await priorPinTask?.value
                _ = try? await priorNavigation?.value
                guard !Task.isCancelled,
                      let self,
                      self.sessionPinGeneration == pinGeneration
                else { return }
                await self.handleRestoredSessionPinFailure(for: account, error: error, pinGeneration: pinGeneration)
            }
            return
        }
        guard self.verifiedAccountId != account.id else {
            self.logger.debug("AccountService: Restored session identity already verified for \(account.name)")
            return
        }
        let expectedBrandId = account.brandId
        let accountId = account.id
        let switchGenerationAtPinStart = self.switchGeneration

        self.sessionPinGeneration &+= 1
        let pinGeneration = self.sessionPinGeneration

        self.sessionPinTask = Task { [weak self, priorPinTask, priorNavigation] in
            defer {
                if let self, self.sessionPinGeneration == pinGeneration {
                    self.sessionPinTask = nil
                }
            }
            await priorPinTask?.value
            _ = try? await priorNavigation?.value
            guard !Task.isCancelled else { return }
            do {
                try await webKitManager.switchSessionIdentity(to: signinURL, expectedBrandId: expectedBrandId)
                guard let self, !Task.isCancelled else { return }
                guard self.currentAccount?.id == accountId,
                      self.switchGeneration == switchGenerationAtPinStart,
                      self.activeSwitchNavigation == nil
                else {
                    self.logger.info("AccountService: Restored session identity for \(account.name) was superseded; not marking verified")
                    return
                }
                self.logger.info("AccountService: Restored session identity for \(account.name)")
                self.markIdentityVerified(account.id)
            } catch is CancellationError {
                // Superseded
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.sessionPinGeneration == pinGeneration
                else { return }
                await self.handleRestoredSessionPinFailure(for: account, error: error, pinGeneration: pinGeneration)
            }
        }
    }

    private func handleRestoredSessionPinFailure(for account: UserAccount, error: Error, pinGeneration: Int) async {
        guard self.currentAccount?.id == account.id else { return }
        self.logger.error("AccountService: Could not restore session identity: \(error.localizedDescription)")
        self.lastError = error
        self.lastErrorWasFetch = false
        self.errorSequence += 1
        guard account.brandId != nil else { return }

        let fallback = self.accounts.first(where: { $0.isPrimary }) ?? self.accounts.first
        guard let fallback, fallback.id != account.id
        else { return }

        var didVerifyFallback = false
        if let webKitManager = self.webKitManager, let fallbackSigninURL = fallback.signinURL {
            do {
                try await self.runTrackedSessionSwitch(
                    with: webKitManager,
                    to: fallbackSigninURL,
                    expectedBrandId: fallback.brandId
                )
                didVerifyFallback = true
            } catch {
                self.logger.error("AccountService: Could not restore fallback session identity: \(error.localizedDescription)")
            }
        }
        guard self.sessionPinGeneration == pinGeneration else { return }

        self.ytMusicClient.resetSessionStateForAccountSwitch()
        self.currentAccount = fallback
        UserDefaults.standard.set(fallback.id, forKey: self.selectedBrandIdKey)
        self.markIdentityVerified(didVerifyFallback ? fallback.id : nil)
    }

    func awaitRestoredSessionPinForTesting() async {
        await self.sessionPinTask?.value
    }

    func prepareForSignOut() async {
        self.accountDataGeneration &+= 1
        self.switchGeneration &+= 1

        let pinTask = self.sessionPinTask
        let navigationTask = self.activeSwitchNavigation
        self.sessionPinTask = nil
        self.activeSwitchNavigation = nil

        pinTask?.cancel()
        navigationTask?.cancel()

        await pinTask?.value
        _ = try? await navigationTask?.value
    }

    /// Switches to a different account.
    func switchAccount(to account: UserAccount) async throws {
        var account = account
        let isSameAccount = account.id == self.currentAccount?.id
        let hadInFlightSessionMutation = self.sessionPinTask != nil || self.activeSwitchNavigation != nil
        if isSameAccount, hadInFlightSessionMutation {
            self.logger.info("AccountService: Cancelling pending session mutation for same-account no-op")
            self.switchGeneration &+= 1
            let cancelGeneration = self.switchGeneration
            let pinTask = self.sessionPinTask
            let navigationTask = self.activeSwitchNavigation
            if pinTask != nil {
                self.sessionPinGeneration &+= 1
            }
            self.sessionPinTask = nil
            self.activeSwitchNavigation = nil
            pinTask?.cancel()
            navigationTask?.cancel()
            await pinTask?.value
            _ = try? await navigationTask?.value
            guard cancelGeneration == self.switchGeneration,
                  self.currentAccount?.id == account.id
            else { return }

            if account.signinURL == nil,
               let refreshedAccount = await self.refreshAccountForRollback(matching: account)
            {
                account = refreshedAccount
            }
            guard cancelGeneration == self.switchGeneration,
                  self.currentAccount?.id == account.id
            else { return }
            guard account.signinURL != nil else { return }
            self.markIdentityVerified(nil)
        }
        guard !isSameAccount || (account.signinURL != nil && self.verifiedAccountId != account.id && self.webKitManager != nil) else {
            self.logger.debug("AccountService: Already using account \(account.name)")
            return
        }
        if isSameAccount {
            self.logger.info("AccountService: Retrying unverified session identity for account: \(account.name)")
        }

        let previousAccount = self.currentAccount
        var rollbackAccount = previousAccount
        self.logger.info("AccountService: Switching to account: \(account.name)")
        self.isLoading = true
        self.manualSwitchInFlightCount += 1
        defer {
            self.manualSwitchInFlightCount -= 1
        }

        self.switchGeneration &+= 1
        let myGeneration = self.switchGeneration
        var cancelledPriorSessionMutation = false

        if self.sessionPinTask != nil || self.activeSwitchNavigation != nil {
            cancelledPriorSessionMutation = true
        }
        let priorPinTask = self.sessionPinTask
        let priorNavigation = self.activeSwitchNavigation
        if priorPinTask != nil {
            self.sessionPinGeneration &+= 1
        }
        priorPinTask?.cancel()
        priorNavigation?.cancel()
        await priorPinTask?.value
        self.sessionPinTask = nil
        guard myGeneration == self.switchGeneration else {
            self.logger.info("AccountService: Switch to \(account.name) superseded before navigation; abandoning")
            self.isLoading = false
            return
        }
        _ = try? await priorNavigation?.value
        if let priorNavigation, self.activeSwitchNavigation == priorNavigation {
            self.activeSwitchNavigation = nil
        }
        guard myGeneration == self.switchGeneration else {
            self.logger.info("AccountService: Switch to \(account.name) superseded while awaiting prior navigation; abandoning")
            self.isLoading = false
            return
        }

        if !UITestConfig.isUITestMode,
           self.webKitManager != nil,
           let previous = rollbackAccount,
           previous.signinURL == nil
        {
            rollbackAccount = await self.refreshAccountForRollback(matching: previous) ?? previous
            guard myGeneration == self.switchGeneration else {
                self.logger.info("AccountService: Switch to \(account.name) superseded while refreshing rollback token; abandoning")
                self.isLoading = false
                return
            }
        }

        var didStartSessionSwitch = false

        defer {
            self.isLoading = false
        }

        do {
            if UITestConfig.isUITestMode,
               UITestConfig.environmentValue(for: UITestConfig.mockAccountSwitchFailKey) == "true"
            {
                throw YTMusicError.apiError(message: "Mock account switch failure", code: nil)
            }

            if !UITestConfig.isUITestMode, let webKitManager = self.webKitManager {
                guard let signinURL = account.signinURL else {
                    throw SessionSwitchError.identityNotApplied(expectedBrandId: account.brandId)
                }
                didStartSessionSwitch = true
                self.markIdentityVerified(nil)
                try await self.runTrackedSessionSwitch(
                    with: webKitManager,
                    to: signinURL,
                    expectedBrandId: account.brandId
                )
            }

            guard myGeneration == self.switchGeneration else {
                self.logger.info("AccountService: Switch to \(account.name) superseded; abandoning commit")
                self.isLoading = false
                return
            }

            // Update local state
            self.currentAccount = account

            // Reset client session state to avoid leaking continuations across accounts
            self.ytMusicClient.resetSessionStateForAccountSwitch()

            // Trigger WebView reload to sync sessions
            SingletonPlayerWebView.shared.reloadForAccountChange()

            let brandLabel = account.brandId ?? "primary"
            self.logger.info("AccountService: Active account brandId=\(brandLabel)")

            // Persist selection
            UserDefaults.standard.set(account.id, forKey: self.selectedBrandIdKey)

            self.markIdentityVerified(account.id)
            self.logger.info("AccountService: Successfully switched to account: \(account.name)")
        } catch {
            self.logger.error("AccountService: Failed to switch account: \(error.localizedDescription)")

            guard myGeneration == self.switchGeneration else {
                self.logger.info("AccountService: Failed switch to \(account.name) was superseded; not reverting")
                throw error
            }

            let restoredPreviousAccount = await self.rollbackSessionAfterFailedSwitch(
                didStartSessionSwitch: didStartSessionSwitch || cancelledPriorSessionMutation,
                previousAccount: rollbackAccount,
                generation: myGeneration
            )
            guard myGeneration == self.switchGeneration else {
                self.logger.info("AccountService: Failed switch to \(account.name) was superseded during rollback; not surfacing failure")
                throw error
            }

            self.currentAccount = restoredPreviousAccount
            self.lastError = error
            self.lastErrorWasFetch = false
            self.errorSequence += 1

            if didStartSessionSwitch {
                Task { [weak self] in await self?.refreshAccountsAfterSwitchFailure() }
            }

            throw error
        }
    }

    private func refreshAccountsAfterSwitchFailure() async {
        guard !self.isLoading else { return }
        await self.fetchAccounts()
    }

    private func rollbackSessionAfterFailedSwitch(
        didStartSessionSwitch: Bool,
        previousAccount: UserAccount?,
        generation: Int
    ) async -> UserAccount? {
        var restoredPreviousAccount = previousAccount
        if didStartSessionSwitch,
           !UITestConfig.isUITestMode,
           let previous = previousAccount,
           let freshPrevious = await self.refreshAccountForRollback(matching: previous)
        {
            restoredPreviousAccount = freshPrevious
        }
        guard generation == self.switchGeneration else {
            return restoredPreviousAccount
        }

        guard didStartSessionSwitch,
              !UITestConfig.isUITestMode,
              let webKitManager = self.webKitManager,
              let previous = restoredPreviousAccount,
              let previousSigninURL = previous.signinURL
        else {
            return restoredPreviousAccount
        }

        do {
            try await self.runTrackedSessionSwitch(
                with: webKitManager,
                to: previousSigninURL,
                expectedBrandId: previous.brandId
            )
            if generation == self.switchGeneration {
                self.markIdentityVerified(previous.id)
            }
        } catch is CancellationError {
            // Superseded
        } catch {
            self.logger.error("AccountService: Session rollback failed: \(error.localizedDescription)")
        }
        return restoredPreviousAccount
    }

    private func refreshAccountForRollback(matching account: UserAccount) async -> UserAccount? {
        do {
            let response = try await self.ytMusicClient.fetchAccountsList()
            return response.accounts.first { $0.id == account.id }
        } catch {
            self.logger.error("AccountService: Could not refresh rollback account token: \(error.localizedDescription)")
            return nil
        }
    }

    /// Clears all account data.
    func clearAccounts() {
        self.logger.info("AccountService: Clearing accounts data")
        self.accountDataGeneration &+= 1
        self.sessionPinGeneration &+= 1

        self.sessionPinTask?.cancel()
        self.sessionPinTask = nil
        self.activeSwitchNavigation?.cancel()
        self.activeSwitchNavigation = nil
        self.switchGeneration &+= 1

        self.accounts = []
        self.currentAccount = nil
        self.verifiedAccountId = nil
        UserDefaults.standard.removeObject(forKey: self.selectedBrandIdKey)
        TrackLikeStatusManager.shared.clearCache()

        self.logger.debug("AccountService: Accounts cleared")
    }

    /// Clears the last error after it has been displayed.
    func clearError() {
        self.lastError = nil
        self.lastErrorWasFetch = false
    }
}

# AGENTS.md

Guidance for AI coding assistants (Claude, GitHub Copilot, Cursor, etc.) working on this repository.

## Role

You are a Senior Swift Engineer specializing in SwiftUI, Swift Concurrency, and macOS development. Your code must adhere to Apple's Human Interface Guidelines. Target **Swift 6.0+** and **macOS 15.0+**.

## What is OptiTube?

A native **macOS** YouTube Music client built with **Swift** and **SwiftUI**.

- **Apple Music-style UI**: Liquid Glass player bar, clean sidebar navigation
- **Browser-cookie authentication**: Auto-extracts cookies from an in-app login WebView
- **Hidden WebView playback**: Singleton WebView for YouTube Music Premium (DRM content)
- **Background audio**: Audio continues when window is closed, stops on quit
- **Native UI**: SwiftUI sidebar navigation, player bar, and content views
- **System integration**: Now Playing in Control Center, media keys, Dock menu

## Project Structure

```
App/                → App entry point, AppDelegate (window lifecycle)
Core/
  ├── Models/       → Data models (Track, Playlist, Album, Artist, etc.)
  ├── Services/
  │   ├── API/      → YTMusicClient, Parsers/ (response parsing)
  │   ├── Auth/     → AuthService (login state machine)
  │   ├── Player/   → PlaybackStore, NowPlayingManager (playback, media keys)
  │   └── WebKit/   → WebKitManager (cookie store, persistent login)
  ├── ViewModels/   → HomeViewModel, LibraryViewModel, SearchViewModel
  └── Utilities/    → DiagnosticsLogger, extensions
Views/
  └── macOS/        → SwiftUI views (MainWindow, Sidebar, PlayerBar, etc.)
Tests/              → Unit tests (OptiTubeTests/)
Tools/              → Standalone CLI tools (api-explorer.swift)
docs/               → Detailed documentation
  └── adr/          → Architecture Decision Records
```

## Documentation

For detailed information, see the `docs/` folder:

- **[docs/architecture.md](docs/architecture.md)** — Services, state management, data flow
- **[docs/playback.md](docs/playback.md)** — WebView playback system, background audio
- **[docs/testing.md](docs/testing.md)** — Test commands, patterns, debugging
- **[docs/adr/](docs/adr/)** — Architecture Decision Records (ADRs)

## Before You Start

1. **Understand the playback architecture** — See [docs/playback.md](docs/playback.md)
2. **Check ADRs for past decisions** — See [docs/adr/](docs/adr/) before proposing architectural changes
3. **Consult API documentation before implementing API features** — See [docs/api-discovery.md](docs/api-discovery.md) for endpoint reference

### API Discovery Workflow

>  **MANDATORY**: Before implementing ANY feature that requires a new or modified API call, you MUST explore the endpoint first using the API Explorer tool. Do NOT guess or assume API response structures.

#### Step 1: Explore with Standalone Tool (Required)

Use the standalone CLI tool to explore endpoints **before writing any code**:

```bash
# Check authentication status
./Tools/api-explorer.swift auth

# List all known endpoints
./Tools/api-explorer.swift list

# Explore public browse endpoints
./Tools/api-explorer.swift browse FEmusic_charts
./Tools/api-explorer.swift browse FEmusic_moods_and_genres

# Explore authenticated endpoints (requires OptiTube sign-in)
./Tools/api-explorer.swift browse FEmusic_liked_playlists
./Tools/api-explorer.swift browse FEmusic_history

# Explore with verbose output to see raw JSON
./Tools/api-explorer.swift browse FEmusic_home -v

# Explore action endpoints
./Tools/api-explorer.swift action search '{"query":"taylor swift"}'
./Tools/api-explorer.swift action player '{"videoId":"dQw4w9WgXcQ"}'
```

The tool automatically uses cookies from the OptiTube app for authenticated endpoints.

#### Step 2: Check Documentation

Review [docs/api-discovery.md](docs/api-discovery.md) to see if the endpoint is already documented with its auth requirements and response structure.

#### Step 3: For Authenticated Endpoints ()

If the endpoint requires authentication:
1. Run `./Tools/api-explorer.swift auth` to check cookie status
2. If no cookies, run the OptiTube app and sign in to YouTube Music
3. The app stores cookies in Keychain; Debug builds also export cookies to `~/Library/Application Support/OptiTube/cookies.dat` for tooling
4. Run the API explorer again

#### Step 4: Document Findings

If you discover new response structures or endpoint behaviors, update [docs/api-discovery.md](docs/api-discovery.md) with your findings.

>  **Do NOT guess API structures** — Always verify with the API Explorer tool or documentation before writing parsers. Incorrect assumptions lead to runtime failures.

## Critical Rules

>  **NEVER leak secrets, cookies, API keys, or tokens** — Under NO circumstances include real cookies, authentication tokens, API keys, SAPISID values, or any sensitive credentials in code, comments, logs, documentation, test fixtures, or any output. Always use placeholder values like `"REDACTED"`, `"mock-token"`, or `"test-cookie"` in examples and tests. This applies to all files including tests, docs, and ADRs. **Violation of this rule is a critical security incident.**

>  **NEVER run `git commit` or `git push`** — Always leave committing and pushing to the human.

>  **ALWAYS confirm before running UI tests** — UI tests launch the app and can be disruptive. Ask the human for permission before executing any UI test.

>  **No Third-Party Frameworks** — Do not introduce third-party dependencies without asking first.

>  **Prefer API over WebView** — Always use `YTMusicClient` API calls when functionality exists. Only use WebView for playback (DRM-protected audio) and authentication. API calls are faster, more testable, and reduce WebView complexity.

>  **Document Architectural Decisions** — For significant design changes, create an ADR in `docs/adr/` following the format in [docs/adr/README.md](docs/adr/README.md).

>  **Document Your Prompts** — When completing a task, summarize the key prompt(s) used so the human can include them in the PR. This supports the project's "prompt request" workflow where prompts are reviewed alongside (or instead of) code. See [CONTRIBUTING.md](CONTRIBUTING.md#ai-assisted-contributions--prompt-requests).

>  **Performance Awareness** — For non-trivial features, run performance tests and verify no anti-patterns. When adding parsers or API calls, include `measure {}` tests.

>  **Improve API Explorer, Don't Write One-Off Scripts** — When exploring or debugging API-related functionality, **always enhance `Tools/api-explorer.swift`** instead of writing temporary scripts. This ensures the tool grows with the project, maintains consistency, and provides reusable functionality for future API work. If you need to fetch raw JSON, test a new endpoint, or debug response parsing, add that capability to the API explorer.

### Build & Verify

After modifying code, verify the build:

```bash
xcodebuild -scheme OptiTube -destination 'platform=macOS' build
```

### Code Quality

```bash
swiftlint --strict && swiftformat .
```

>  **SwiftFormat `--self insert` rule**: The project uses `--self insert` in `.swiftformat`. This means:
> - In static methods, call other static methods with `Self.methodName()` (not bare `methodName()`)
> - In instance methods, use `self.property` explicitly
>
> Always run `swiftformat .` before completing work to auto-fix these issues.

### Modern SwiftUI APIs

|  Avoid |  Use |
|----------|--------|
| `.foregroundColor()` | `.foregroundStyle()` |
| `.cornerRadius()` | `.clipShape(.rect(cornerRadius:))` |
| `onChange(of:) { newValue in }` | `onChange(of:) { _, newValue in }` |
| `Task.sleep(nanoseconds:)` | `Task.sleep(for: .seconds())` |
| `NavigationView` | `NavigationSplitView` or `NavigationStack` |
| `onTapGesture()` | `Button` (unless tap location needed) |
| `tabItem()` | `Tab` API |
| `AnyView` | Concrete types or `@ViewBuilder` |
| `print()` | `DiagnosticsLogger` |
| `DispatchQueue` | Swift concurrency (`async`/`await`) |
| `String(format: "%.2f", n)` | `Text(n, format: .number.precision(...))` |
| Force unwraps (`!`) | Optional handling or `guard` |
| Image-only buttons without labels | Add `.accessibilityLabel()` |
| `.background(.ultraThinMaterial)` | `.glassEffect()` for macOS 26+ |

### Liquid Glass UI (macOS 26+)

> See [docs/architecture.md#ui-design-macos-26](docs/architecture.md#ui-design-macos-26) for detailed patterns.

**Quick Rules**:
- Use `.glassEffect(.regular.interactive(), in: .capsule)` for interactive elements
- Wrap multiple glass elements in `GlassEffectContainer`
- Add `PlayerBar` via `safeAreaInset` to every navigable view
- Avoid glass-on-glass (no `.buttonStyle(.glass)` inside glass containers)

### Swift Testing (Preferred)

>  **Use Swift Testing for all new unit tests** — See [docs/testing.md](docs/testing.md) and [ADR-0006](docs/adr/0006-swift-testing-migration.md) for full patterns.

**Quick Reference**:
- Use `@Suite struct` + `@Test func` (not XCTest)
- Use `#expect(a == b)` (not `XCTAssertEqual`)
- Use `.serialized` for `@MainActor` test suites
- Keep performance tests (`measure {}`) and UI tests in XCTest

### Swift Concurrency

- Mark `@Observable` classes with `@MainActor`
- Never use `DispatchQueue` — use `async`/`await`, `MainActor`

### Common Bug Patterns to Avoid

These patterns have caused bugs in this codebase. **Always check for these during code review.**

####  Fire-and-Forget Tasks

```swift
//  BAD: Task not tracked, errors lost, can't cancel
func likeTrack() {
    Task { await api.like(trackId) }
}

//  GOOD: Track task, handle errors, support cancellation
private var likeTask: Task<Void, Error>?

func likeTrack() async throws {
    likeTask?.cancel()
    likeTask = Task {
        try await api.like(trackId)
    }
    try await likeTask?.value
}
```

####  Optimistic Updates Without Proper Rollback

```swift
//  BAD: CancellationError not handled, cache permanently wrong
func rate(_ track: Track, status: LikeStatus) async {
    let previous = cache[track.id]
    cache[track.id] = status  // Optimistic update
    do {
        try await api.rate(track.id, status)
    } catch {
        cache[track.id] = previous  // Doesn't run on cancellation!
    }
}

//  GOOD: Handle ALL errors including cancellation
func rate(_ track: Track, status: LikeStatus) async {
    let previous = cache[track.id]
    cache[track.id] = status
    do {
        try await api.rate(track.id, status)
    } catch let error as CancellationError {
        cache[track.id] = previous  // Rollback on cancel
        throw error  // Propagate original cancellation
    } catch {
        cache[track.id] = previous  // Rollback on error
        throw error
    }
}
```

####  Static Shared Singletons with Mutable Assignment

```swift
//  BAD: Race condition if multiple instances created
class LibraryViewModel {
    static var shared: LibraryViewModel?
    init() { Self.shared = self }  // Overwrites previous!
}

//  GOOD: Use SwiftUI Environment for dependency injection
@Observable @MainActor
class LibraryViewModel { /* ... */ }

// In parent view:
.environment(libraryViewModel)

// In child view:
@Environment(LibraryViewModel.self) var viewModel
```

####  `.onAppear` Instead of `.task` for Async Work

```swift
//  BAD: Task not cancelled on disappear, can update stale view
.onAppear {
    Task { await viewModel.load() }
}

//  GOOD: Lifecycle-managed, auto-cancelled on disappear
.task {
    await viewModel.load()
}

//  GOOD: With ID for re-execution on change
.task(id: playlistId) {
    await viewModel.load(playlistId)
}
```

####  ForEach with Unstable Identity

```swift
//  BAD: Index-based identity causes wrong views during mutations
ForEach(tracks.indices, id: \.self) { index in
    TrackRow(track: tracks[index])
}

//  BAD: Array enumeration recreates identity on every change
ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
    TrackRow(track: track, rank: index + 1)
}

//  GOOD: Use stable model identity
ForEach(tracks) { track in
    TrackRow(track: track)
}

//  GOOD: If you need index for display (charts), use element ID
ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
    TrackRow(track: track, rank: index + 1)
}
```

####  Background Tasks Not Cancelled on Deinit

```swift
//  BAD: Task continues after ViewModel is deallocated
@Observable @MainActor
class HomeViewModel {
    private var backgroundTask: Task<Void, Never>?

    func startLoading() {
        backgroundTask = Task { /* ... */ }
    }
    // Missing deinit cleanup!
}

//  GOOD: Cancel tasks in deinit
@Observable @MainActor
class HomeViewModel {
    private var backgroundTask: Task<Void, Never>?

    func startLoading() {
        backgroundTask?.cancel()
        backgroundTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            // ...
        }
    }

    deinit {
        backgroundTask?.cancel()
    }
}
```

####  Shared Continuation Tokens Across Different Requests

```swift
//  BAD: Single token for all search types causes conflicts
class YTMusicClient {
    private var searchContinuationToken: String?  // Shared!

    func searchTracks() { /* sets token */ }
    func searchAlbums() { /* overwrites token! */ }
}

//  GOOD: Scope tokens by request type or return in response
class YTMusicClient {
    private var continuationTokens: [String: String] = [:]

    func searchTracks() -> (tracks: [Track], continuation: String?) {
        // Return token with response, let caller manage
    }
}
```

### WebKit Patterns

- Use `WebKitManager`'s shared `WKWebsiteDataStore` for cookie persistence
- Use `SingletonPlayerWebView.shared` for playback (never create multiple WebViews)
- Compute `SAPISIDHASH` fresh per request using current cookies

### Error Handling

- Throw `YTMusicError.authExpired` on HTTP 401/403
- Use `DiagnosticsLogger` for all logging (not `print()`)
- Show user-friendly error messages with retry options

## Key Files

| File | Purpose |
|------|---------|
| `Tools/api-explorer.swift` | **Standalone API explorer CLI** (run before implementing API features) |
| `App/AppDelegate.swift` | Window lifecycle, background audio support |
| `Core/Services/WebKit/WebKitManager.swift` | Cookie store & persistence |
| `Core/Services/Auth/AuthService.swift` | Login state machine |
| `Core/Services/Player/PlaybackStore.swift` | Playback state & control |
| `Views/macOS/MiniPlayerWebView.swift` | Singleton WebView, playback UI |
| `Views/macOS/MainWindow.swift` | Main app window |
| `Core/Utilities/DiagnosticsLogger.swift` | Logging |

## Quick Reference

> See [docs/testing.md](docs/testing.md) for full test commands and patterns.

### Build Commands

```bash
# Build
xcodebuild -scheme OptiTube -destination 'platform=macOS' build

# Unit Tests
xcodebuild -scheme OptiTube -destination 'platform=macOS' test -only-testing:OptiTubeTests

# Lint & Format
swiftlint --strict && swiftformat .
```

### Test Execution Rules

>  **NEVER run unit tests and UI tests together** — Always execute them separately.

**UI Tests** — Ask permission first, run ONE at a time:
```bash
xcodebuild -scheme OptiTube -destination 'platform=macOS' test \
  -only-testing:OptiTubeUITests/TestClassName/testMethodName
```

## Architecture Overview

> See [docs/architecture.md](docs/architecture.md) and [docs/playback.md](docs/playback.md) for detailed flows.

**Key Concepts**:
- **Singleton WebView** for playback (DRM requires WebKit)
- **Background audio** via `windowShouldClose` returning `false` (hides instead of closes)
- **Cookie-based auth** with `__Secure-3PAPISID` extracted from WebView
- **API-first** — use `YTMusicClient` for data, WebView only for playback/auth

## Performance Checklist

Before completing non-trivial features, verify:

- [ ] No `await` calls inside loops or `ForEach`
- [ ] Lists use `LazyVStack`/`LazyHStack` for large datasets
- [ ] Network calls cancelled on view disappear (`.task` handles this)
- [ ] Parsers have `measure {}` tests if processing large payloads
- [ ] Images use `ImageCache` with appropriate `targetSize` (not loading inline)
- [ ] Search input is debounced (not firing on every keystroke)
- [ ] ForEach uses stable identity (avoid `Array(enumerated())` unless rank is needed)
- [ ] Frequently updating UI (e.g., progress) caches formatted strings

## Concurrency Safety Checklist

Before completing features with async code, verify:

- [ ] No fire-and-forget `Task { }` without error handling
- [ ] Optimistic updates handle `CancellationError` explicitly
- [ ] Background tasks cancelled in `deinit`
- [ ] Using `.task` instead of `.onAppear { Task { } }`
- [ ] Continuation tokens scoped per-request (not shared across types)
- [ ] No `static var shared` pattern with mutable assignment in `init`
- [ ] WebView message handlers removed in `dismantleNSView`
- [ ] `WKNavigationDelegate` implements `webViewWebContentProcessDidTerminate`

>  See [docs/architecture.md#performance-guidelines](docs/architecture.md#performance-guidelines) for detailed patterns.

## Task Planning: Phases with Exit Criteria

For any non-trivial task, **plan in phases with testable exit criteria** before writing code. This ensures incremental progress and early detection of issues.

### Phase Structure

Every task should be broken into phases. Each phase must have:
1. **Clear deliverable** — What artifact or change is produced
2. **Testable exit criteria** — How to verify the phase is complete
3. **Rollback point** — The phase should leave the codebase in a working state

### Standard Phases

#### Phase 1: Research & Understanding
| Deliverable | Exit Criteria |
|-------------|---------------|
| Identify affected files and dependencies | List all files to modify/create |
| Understand existing patterns | Can explain how similar features work |
| Read relevant docs | Confirmed patterns in `docs/` apply |

**Exit gate**: Can articulate the implementation plan without ambiguity.

#### Phase 2: Interface Design
| Deliverable | Exit Criteria |
|-------------|---------------|
| Define new types/protocols | Type signatures compile |
| Plan public API surface | No breaking changes to existing callers (or changes identified) |

**Exit gate**: `xcodebuild build` succeeds with stub implementations.

#### Phase 3: Core Implementation
| Deliverable | Exit Criteria |
|-------------|---------------|
| Implement business logic | Unit tests pass for new code |
| Handle error cases | Error paths have test coverage |
| Add logging | `DiagnosticsLogger` calls in place |
| Performance verified | Anti-pattern checklist passed, perf tests added if applicable |

**Exit gate**: `xcodebuild test -only-testing:OptiTubeTests` passes.

#### Phase 4: Quality Assurance
| Deliverable | Exit Criteria |
|-------------|---------------|
| Linting passes | `swiftlint --strict` reports 0 errors |
| Formatting applied | `swiftformat .` makes no changes |
| Full test suite passes | `xcodebuild test` succeeds |

**Exit gate**: CI-equivalent checks pass locally.

### Example: Adding a New Service

```
Phase 1: Research
├── Exit: Understand YTMusicClient pattern, confirm no existing solution

Phase 2: Interface
├── Create NewService.swift with protocol + stub
├── Exit: `xcodebuild build` passes

Phase 3: Implementation
├── Implement methods, add error handling
├── Create NewServiceTests.swift
├── Exit: `xcodebuild test -only-testing:OptiTubeTests/NewServiceTests` passes

Phase 4: QA
├── Run swiftlint, swiftformat
├── Exit: Full test suite passes, no lint errors
```

### Checkpoint Communication

After each phase, briefly report:
-  What was completed
-  Test/verification results
-  Next phase plan

This keeps the human informed and provides natural points to course-correct.

## Subagents (Context-Isolated Tasks)

VS Code's `#runSubagent` tool enables context-isolated task execution. Subagents run independently with their own context, preventing context confusion in complex tasks.

### When to Use Subagents

| Task Type | Use Subagent? | Rationale |
|-----------|---------------|-----------|
| Research API endpoints |  Yes | Keeps raw JSON exploration out of main context |
| Analyze unfamiliar code areas |  Yes | Deep dives don't pollute main conversation |
| Review a single file for patterns |  Yes | Focused analysis, returns summary only |
| Generate test fixtures |  Yes | Boilerplate generation isolated from design discussion |
| Simple edits to known files |  No | Direct action is faster |
| Multi-step refactoring |  No | Needs continuous context across steps |
| Tasks requiring user feedback |  No | Subagents don't pause for input |

### Subagent Prompts for This Project

**API Research** — Explore an endpoint before implementing:
```
Analyze the YouTube Music API endpoint structure for #file:docs/api-discovery.md with #runSubagent.
Focus on FEmusic_liked_playlists response format and identify all playlist item fields.
Return a summary of the response structure suitable for writing a parser.
```

**Code Pattern Analysis** — Understand existing patterns:
```
With #runSubagent, analyze #file:Core/Services/API/YTMusicClient.swift and identify:
1. How authenticated requests are constructed
2. Error handling patterns
3. How parsers are invoked
Return a concise pattern guide for adding a new endpoint method.
```

**Parser Stub Generation** — Generate boilerplate:
```
Using #runSubagent, generate a Swift parser struct following the pattern in #file:Core/Services/API/Parsers/
for parsing a "moods and genres" API response with categories containing playlists.
Return only the struct definition with placeholder parsing logic.
```

**Performance Audit** — Isolated deep dive:
```
With #runSubagent, audit #file:Views/macOS/LibraryView.swift for SwiftUI performance issues.
Check for: await in ForEach, missing LazyVStack, inline image loading, excessive state updates.
Return a prioritized list of issues with line numbers.
```

### Subagent Best Practices

1. **Be specific in prompts** — Subagents don't have conversation history; include all necessary context
2. **Request structured output** — Ask for summaries, lists, or code snippets that integrate cleanly
3. **Use for exploration, not execution** — Subagents are great for research; keep edits in main context
4. **Combine with file references** — Use `#file:path` to give subagents focused context
5. **Review before integrating** — Subagent results join main context; verify accuracy first

### Anti-Patterns

-  Using subagents for quick lookups (overhead not worth it)
-  Chaining multiple subagents (use main context for multi-step work)
-  Expecting subagents to remember previous subagent results
-  Using subagents for tasks requiring user clarification

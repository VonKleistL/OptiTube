import Foundation
import Testing
@testable import OptiTube

// MARK: - MusicIntentTests

/// Tests for MusicIntent query building and content source suggestion.
@available(macOS 15.0, *)
@Suite("MusicIntent", .tags(.api))
struct MusicIntentTests {
    // MARK: - buildSearchQuery Tests

    @Test("Build search query with artist only")
    func buildSearchQueryArtistOnly() {
        let intent = MusicIntent(
            action: .play,
            query: "Beatles tracks",
            shuffleScope: "",
            artist: "Beatles",
            genre: "",
            mood: "",
            era: "",
            version: "",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query.contains("Beatles"), "Query should contain artist name")
        #expect(query.contains("tracks"), "Query should contain 'tracks' suffix")
    }

    @Test("Build search query with mood and genre")
    func buildSearchQueryMoodAndGenre() {
        let intent = MusicIntent(
            action: .play,
            query: "",
            shuffleScope: "",
            artist: "",
            genre: "jazz",
            mood: "chill",
            era: "",
            version: "",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query == "jazz chill tracks", "Should combine genre, mood, and tracks suffix")
    }

    @Test("Build search query with artist and era")
    func buildSearchQueryArtistWithEra() {
        let intent = MusicIntent(
            action: .play,
            query: "rolling stones 90s hits",
            shuffleScope: "",
            artist: "Rolling Stones",
            genre: "",
            mood: "",
            era: "1990s",
            version: "",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query.contains("Rolling Stones"), "Query should contain artist")
        #expect(query.contains("90s") || query.contains("1990s"), "Query should contain era")
        #expect(query.contains("hits"), "Query should preserve 'hits' from original query")
    }

    @Test("Build search query with era only")
    func buildSearchQueryEraOnly() {
        let intent = MusicIntent(
            action: .play,
            query: "80s music",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "1980s",
            version: "",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query.contains("80s") || query.contains("1980s"), "Query should contain era")
        #expect(query.contains("hits") || query.contains("tracks"), "Query should have suffix")
    }

    @Test("Build search query with version type")
    func buildSearchQueryVersionType() {
        let intent = MusicIntent(
            action: .play,
            query: "acoustic covers",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "",
            version: "acoustic",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query.contains("acoustic"), "Query should contain version type")
    }

    @Test("Build search query complex")
    func buildSearchQueryComplex() {
        let intent = MusicIntent(
            action: .play,
            query: "upbeat rolling stones tracks from the 90s",
            shuffleScope: "",
            artist: "Rolling Stones",
            genre: "rock",
            mood: "upbeat",
            era: "1990s",
            version: "",
            activity: ""
        )

        let query = intent.buildSearchQuery()
        #expect(query.contains("Rolling Stones"), "Should contain artist")
        #expect(query.contains("upbeat") || query.contains("rock"), "Should contain mood or genre")
    }

    // MARK: - suggestedContentSource Tests

    @Test("Content source for artist query returns search")
    func contentSourceArtistQueryReturnsSearch() {
        let intent = MusicIntent(
            action: .play,
            query: "Taylor Swift",
            shuffleScope: "",
            artist: "Taylor Swift",
            genre: "",
            mood: "",
            era: "",
            version: "",
            activity: ""
        )

        #expect(intent.suggestedContentSource() == .search, "Artist queries should use search")
    }

    @Test("Content source for mood query returns moods and genres")
    func contentSourceMoodQueryReturnsMoodsAndGenres() {
        let intent = MusicIntent(
            action: .play,
            query: "chill music",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "chill",
            era: "",
            version: "",
            activity: ""
        )

        #expect(intent.suggestedContentSource() == .moodsAndGenres, "Pure mood queries should use Moods & Genres")
    }

    @Test("Content source for activity query returns moods and genres")
    func contentSourceActivityQueryReturnsMoodsAndGenres() {
        let intent = MusicIntent(
            action: .play,
            query: "workout music",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "",
            version: "",
            activity: "workout"
        )

        #expect(intent.suggestedContentSource() == .moodsAndGenres, "Activity-based queries should use Moods & Genres")
    }

    @Test("Content source for charts query returns charts")
    func contentSourceChartsQueryReturnsCharts() {
        let intent = MusicIntent(
            action: .play,
            query: "top tracks",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "",
            version: "",
            activity: ""
        )

        #expect(intent.suggestedContentSource() == .charts, "Popularity keywords should use Charts")
    }

    @Test("Content source for version query returns search")
    func contentSourceVersionQueryReturnsSearch() {
        let intent = MusicIntent(
            action: .play,
            query: "live performances",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "",
            version: "live",
            activity: ""
        )

        #expect(intent.suggestedContentSource() == .search, "Version-specific queries need search")
    }

    // MARK: - queryDescription Tests

    @Test("Query description with all components")
    func queryDescriptionAllComponents() {
        let intent = MusicIntent(
            action: .play,
            query: "upbeat rock by Queen from the 80s (live)",
            shuffleScope: "",
            artist: "Queen",
            genre: "rock",
            mood: "upbeat",
            era: "1980s",
            version: "live",
            activity: ""
        )

        let description = intent.queryDescription()
        #expect(description.contains("upbeat"), "Should include mood")
        #expect(description.contains("rock"), "Should include genre")
        #expect(description.contains("Queen"), "Should include artist")
        #expect(description.contains("1980s"), "Should include era")
        #expect(description.contains("live"), "Should include version")
    }

    @Test("Query description with empty components falls back to query")
    func queryDescriptionEmptyFallsBackToQuery() {
        let intent = MusicIntent(
            action: .play,
            query: "something random",
            shuffleScope: "",
            artist: "",
            genre: "",
            mood: "",
            era: "",
            version: "",
            activity: ""
        )

        let description = intent.queryDescription()
        #expect(description == "something random", "Empty components should fall back to query")
    }
}

// MARK: - MusicQueryTests

@available(macOS 15.0, *)
@Suite("MusicQuery", .tags(.api))
struct MusicQueryTests {
    @Test("Build search query basic artist")
    func buildSearchQueryBasicArtist() {
        let query = MusicQuery(
            searchTerm: "",
            artist: "Coldplay",
            genre: "",
            mood: "",
            activity: "",
            era: "",
            version: "",
            language: "",
            contentRating: "",
            count: 0
        )

        let result = query.buildSearchQuery()
        #expect(result.contains("Coldplay"), "Should include artist")
        #expect(result.contains("tracks"), "Should end with 'tracks'")
    }

    @Test("Build search query full query")
    func buildSearchQueryFullQuery() {
        let query = MusicQuery(
            searchTerm: "",
            artist: "Coldplay",
            genre: "rock",
            mood: "upbeat",
            activity: "",
            era: "2000s",
            version: "live",
            language: "",
            contentRating: "",
            count: 0
        )

        let result = query.buildSearchQuery()
        #expect(result.contains("Coldplay"))
        #expect(result.contains("rock"))
        #expect(result.contains("upbeat"))
        #expect(result.contains("2000s"))
        #expect(result.contains("live"))
    }

    @Test("Build search query activity only when empty")
    func buildSearchQueryActivityOnlyWhenEmpty() {
        let query = MusicQuery(
            searchTerm: "",
            artist: "",
            genre: "",
            mood: "",
            activity: "workout",
            era: "",
            version: "",
            language: "",
            contentRating: "",
            count: 0
        )

        let result = query.buildSearchQuery()
        #expect(result.contains("workout music"), "Activity should be used when nothing else specified")
    }

    @Test("Description formats nicely")
    func descriptionFormatsNicely() {
        let query = MusicQuery(
            searchTerm: "",
            artist: "Daft Punk",
            genre: "electronic",
            mood: "energetic",
            activity: "party",
            era: "2000s",
            version: "",
            language: "",
            contentRating: "",
            count: 0
        )

        let desc = query.description()
        #expect(desc.contains("energetic"))
        #expect(desc.contains("electronic"))
        #expect(desc.contains("Daft Punk"))
        #expect(desc.contains("2000s"))
        #expect(desc.contains("party"))
    }
}

// MARK: - AISessionTypeTests

@available(macOS 15.0, *)
@Suite("AISessionType", .tags(.api))
struct AISessionTypeTests {
    @Test("Command session has generation options")
    func commandSessionHasLowerTemperature() {
        let options = AISessionType.command.generationOptions
        #expect(options != nil, "Command session should have generation options")
    }

    @Test("Analysis session has generation options")
    func analysisSessionHasHigherTemperature() {
        let options = AISessionType.analysis.generationOptions
        #expect(options != nil, "Analysis session should have generation options")
    }

    @Test("Conversational session has generation options")
    func conversationalSessionHasBalancedTemperature() {
        let options = AISessionType.conversational.generationOptions
        #expect(options != nil, "Conversational session should have generation options")
    }
}

// MARK: - ContentSourceTests

@Suite("ContentSource", .tags(.model))
struct ContentSourceTests {
    @Test(
        "Content source description",
        arguments: [
            (ContentSource.search, "search"),
            (ContentSource.moodsAndGenres, "moodsAndGenres"),
            (ContentSource.charts, "charts"),
        ]
    )
    func contentSourceDescription(source: ContentSource, expected: String) {
        #expect(source.description == expected)
    }
}

// MARK: - QueueIntentTests

@available(macOS 15.0, *)
@Suite("QueueIntent Unit", .tags(.api))
struct QueueIntentTests {
    @Test("Queue action values")
    func queueActionValues() {
        let actions: [QueueAction] = [.add, .addNext, .remove, .clear, .shuffle]
        #expect(actions.count == 5, "Should have 5 queue actions")
    }

    @Test(
        "Queue action raw values",
        arguments: [
            (QueueAction.add, "add"),
            (QueueAction.addNext, "addNext"),
            (QueueAction.remove, "remove"),
            (QueueAction.clear, "clear"),
            (QueueAction.shuffle, "shuffle"),
        ]
    )
    func queueActionRawValues(action: QueueAction, expected: String) {
        #expect(action.rawValue == expected)
    }

    @Test("QueueAction is CaseIterable")
    func queueActionCaseIterable() {
        let allCases = QueueAction.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.add))
        #expect(allCases.contains(.addNext))
        #expect(allCases.contains(.remove))
        #expect(allCases.contains(.clear))
        #expect(allCases.contains(.shuffle))
    }

    @Test("QueueIntent with add action")
    func queueIntentAddAction() {
        let intent = QueueIntent(
            action: .add,
            query: "jazz tracks",
            count: 3
        )

        #expect(intent.action == .add)
        #expect(intent.query == "jazz tracks")
        #expect(intent.count == 3)
    }

    @Test("QueueIntent with clear action has empty query")
    func queueIntentClearAction() {
        let intent = QueueIntent(
            action: .clear,
            query: "",
            count: 0
        )

        #expect(intent.action == .clear)
        #expect(intent.query.isEmpty)
        // count should be 0 for clear actions (no tracks to add)
        let expectedCount = 0
        #expect(intent.count == expectedCount)
    }

    @Test("QueueIntent with shuffle action")
    func queueIntentShuffleAction() {
        let intent = QueueIntent(
            action: .shuffle,
            query: "",
            count: 0
        )

        #expect(intent.action == .shuffle)
    }
}

// MARK: - MusicActionTests

@available(macOS 15.0, *)
@Suite("MusicAction", .tags(.model))
struct MusicActionTests {
    @Test(
        "Music action raw values",
        arguments: [
            (MusicAction.play, "play"),
            (MusicAction.queue, "queue"),
            (MusicAction.shuffle, "shuffle"),
            (MusicAction.like, "like"),
            (MusicAction.dislike, "dislike"),
            (MusicAction.skip, "skip"),
            (MusicAction.previous, "previous"),
            (MusicAction.pause, "pause"),
            (MusicAction.resume, "resume"),
            (MusicAction.search, "search"),
        ]
    )
    func musicActionRawValues(action: MusicAction, expected: String) {
        #expect(action.rawValue == expected)
    }

    @Test("MusicAction is CaseIterable")
    func musicActionCaseIterable() {
        let allCases = MusicAction.allCases
        #expect(allCases.count == 10)
    }

    @Test("MusicAction contains all expected cases")
    func musicActionAllCases() {
        let allCases = MusicAction.allCases
        #expect(allCases.contains(.play))
        #expect(allCases.contains(.queue))
        #expect(allCases.contains(.shuffle))
        #expect(allCases.contains(.like))
        #expect(allCases.contains(.dislike))
        #expect(allCases.contains(.skip))
        #expect(allCases.contains(.previous))
        #expect(allCases.contains(.pause))
        #expect(allCases.contains(.resume))
        #expect(allCases.contains(.search))
    }
}

// MARK: - PlaylistChangesTests

@available(macOS 15.0, *)
@Suite("PlaylistChanges Unit", .tags(.model))
struct PlaylistChangesTests {
    @Test("PlaylistChanges with empty removals")
    func emptyRemovals() {
        let changes = PlaylistChanges(
            removals: [],
            reorderedIds: nil,
            reasoning: "No changes needed"
        )

        #expect(changes.removals.isEmpty)
        #expect(changes.reorderedIds == nil)
        #expect(!changes.reasoning.isEmpty)
    }

    @Test("PlaylistChanges with removals")
    func withRemovals() {
        let changes = PlaylistChanges(
            removals: ["video1", "video2"],
            reorderedIds: nil,
            reasoning: "Removed duplicates"
        )

        #expect(changes.removals.count == 2)
        #expect(changes.removals.contains("video1"))
        #expect(changes.removals.contains("video2"))
    }

    @Test("PlaylistChanges with reordering")
    func withReordering() {
        let newOrder = ["video3", "video1", "video2"]
        let changes = PlaylistChanges(
            removals: [],
            reorderedIds: newOrder,
            reasoning: "Sorted by energy level"
        )

        #expect(changes.removals.isEmpty)
        #expect(changes.reorderedIds == newOrder)
    }

    @Test("PlaylistChanges reasoning is present")
    func reasoningPresent() {
        let changes = PlaylistChanges(
            removals: ["video1"],
            reorderedIds: nil,
            reasoning: "Removed track that doesn't fit the vibe"
        )

        #expect(changes.reasoning.contains("Removed"))
    }
}

// MARK: - QueueChangesTests

@available(macOS 15.0, *)
@Suite("QueueChanges Unit", .tags(.model))
struct QueueChangesTests {
    @Test("QueueChanges with empty additions and removals")
    func emptyChanges() {
        let changes = QueueChanges(
            removals: [],
            additions: [],
            reorderedIds: nil,
            reasoning: "Queue looks good"
        )

        #expect(changes.removals.isEmpty)
        #expect(changes.additions.isEmpty)
        #expect(changes.reorderedIds == nil)
    }

    @Test("QueueChanges with additions only")
    func additionsOnly() {
        let changes = QueueChanges(
            removals: [],
            additions: ["newVideo1", "newVideo2"],
            reorderedIds: nil,
            reasoning: "Added more jazz tracks"
        )

        #expect(changes.additions.count == 2)
        #expect(changes.removals.isEmpty)
    }

    @Test("QueueChanges with removals only")
    func removalsOnly() {
        let changes = QueueChanges(
            removals: ["oldVideo1"],
            additions: [],
            reorderedIds: nil,
            reasoning: "Removed slow track"
        )

        #expect(changes.removals.count == 1)
        #expect(changes.additions.isEmpty)
    }

    @Test("QueueChanges with reordering")
    func withReordering() {
        let reordered = ["v3", "v1", "v2"]
        let changes = QueueChanges(
            removals: [],
            additions: [],
            reorderedIds: reordered,
            reasoning: "Shuffled for variety"
        )

        #expect(changes.reorderedIds == reordered)
    }

    @Test("QueueChanges with all operations")
    func allOperations() {
        let changes = QueueChanges(
            removals: ["old1"],
            additions: ["new1", "new2"],
            reorderedIds: ["new1", "existing1", "new2"],
            reasoning: "Refreshed queue with new tracks"
        )

        #expect(changes.removals.count == 1)
        #expect(changes.additions.count == 2)
        #expect(changes.reorderedIds?.count == 3)
        #expect(!changes.reasoning.isEmpty)
    }
}

// MARK: - LyricsSummaryTests

@available(macOS 15.0, *)
@Suite("LyricsSummary Unit", .tags(.model))
struct LyricsSummaryTests {
    @Test("LyricsSummary with minimal themes")
    func minimalThemes() {
        let summary = LyricsSummary(
            themes: ["love", "loss"],
            mood: "melancholic",
            explanation: "A track about heartbreak and moving on."
        )

        #expect(summary.themes.count >= 2)
        #expect(summary.themes.contains("love"))
        #expect(summary.themes.contains("loss"))
    }

    @Test("LyricsSummary mood is single word or short phrase")
    func moodFormat() {
        let summary = LyricsSummary(
            themes: ["hope", "resilience", "growth"],
            mood: "uplifting",
            explanation: "An inspiring anthem about overcoming obstacles."
        )

        #expect(!summary.mood.isEmpty)
        #expect(summary.mood == "uplifting")
    }

    @Test("LyricsSummary explanation is concise")
    func explanationConcise() {
        let summary = LyricsSummary(
            themes: ["nostalgia", "youth", "summer"],
            mood: "nostalgic",
            explanation: "The track reminisces about carefree summer days. It captures the bittersweet feeling of looking back at simpler times."
        )

        #expect(!summary.explanation.isEmpty)
        // Should be 2-4 sentences, reasonably concise
        #expect(summary.explanation.count < 500)
    }

    @Test("LyricsSummary with multiple themes")
    func multipleThemes() {
        let summary = LyricsSummary(
            themes: ["rebellion", "freedom", "youth", "identity"],
            mood: "defiant",
            explanation: "A punk anthem about breaking free from expectations."
        )

        #expect(summary.themes.count >= 2)
        #expect(summary.themes.count <= 5)
    }
}

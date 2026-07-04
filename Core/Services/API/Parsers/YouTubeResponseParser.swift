import Foundation

// MARK: - YouTubeResponseParser

/// Parses regular YouTube InnerTube API responses into `YouTubeFeedResponse`.
///
/// Handles renderers from the `WEB` client context, which differ from the
/// `WEB_REMIX` (YouTube Music) renderers. Supported renderer types:
///
/// - `richGridRenderer` / `richItemRenderer` (home, subscriptions)
/// - `videoRenderer` (search results, watch next)
/// - `gridVideoRenderer` (playlist page)
/// - `compactVideoRenderer` (related, history)
/// - `reelItemRenderer` (Shorts)
/// - `playlistRenderer` / `gridPlaylistRenderer`
/// - `channelRenderer` / `gridChannelRenderer`
/// - `itemSectionRenderer` / `shelfRenderer`
/// - `horizontalCardListRenderer`
/// - `continuationItemRenderer`
enum YouTubeResponseParser {
    // MARK: - Public Entry Points

    static func parseFeedResponse(_ json: [String: Any]) -> YouTubeFeedResponse {
        var sections: [YouTubeFeedSection] = []
        var continuationToken: String?

        // Home feed / subscriptions → contents.richGridRenderer.contents
        if let richGrid = self.dig(json, "contents", "richGridRenderer", "contents") as? [[String: Any]] {
            let (items, token) = self.parseRichGridContents(richGrid)
            continuationToken = token
            if !items.isEmpty {
                sections.append(YouTubeFeedSection(id: "main", title: nil, items: items))
            }
        }
        // Trending / explore → contents.twoColumnBrowseResultsRenderer.tabs[0].tabRenderer.content.sectionListRenderer.contents
        else if let tabs = self.dig(json, "contents", "twoColumnBrowseResultsRenderer", "tabs") as? [[String: Any]] {
            let (sects, token) = self.parseTabs(tabs)
            sections = sects
            continuationToken = token
        }
        // Single sectionListRenderer at root level
        else if let sectionContents = self.dig(json, "contents", "sectionListRenderer", "contents") as? [[String: Any]] {
            let (sects, token) = self.parseSectionList(sectionContents)
            sections = sects
            continuationToken = token
        }
        // continuationContents (continuation response)
        else if let contContents = json["continuationContents"] as? [String: Any] {
            if let richGrid = contContents["richGridContinuation"] as? [String: Any],
               let contents = richGrid["contents"] as? [[String: Any]]
            {
                let (items, token) = self.parseRichGridContents(contents)
                continuationToken = token
                if !items.isEmpty {
                    sections.append(YouTubeFeedSection(id: "cont-main", title: nil, items: items))
                }
            } else if let sectionList = contContents["sectionListContinuation"] as? [String: Any],
                      let contents = sectionList["contents"] as? [[String: Any]]
            {
                let (sects, token) = self.parseSectionList(contents)
                sections = sects
                continuationToken = token
            }
        }
        // Modern continuation (action responses like explore/trending or home scrolling)
        else if let commands = (json["onResponseReceivedActions"] as? [[String: Any]]) ??
            (json["onResponseReceivedCommands"] as? [[String: Any]])
        {
            for command in commands {
                if let appendAction = command["appendContinuationItemsAction"] as? [String: Any],
                   let items = appendAction["continuationItems"] as? [[String: Any]]
                {
                    let (sects, token) = self.parseContinuationItems(items)
                    sections.append(contentsOf: sects)
                    if token != nil { continuationToken = token }
                }
            }
        }

        return YouTubeFeedResponse(sections: sections, continuationToken: continuationToken)
    }

    static func parseSearchResponse(_ json: [String: Any]) -> YouTubeFeedResponse {
        var sections: [YouTubeFeedSection] = []
        var continuationToken: String?

        // Search → contents.twoColumnSearchResultsRenderer.primaryContents.sectionListRenderer.contents
        if let sectionContents = self.dig(
            json,
            "contents", "twoColumnSearchResultsRenderer",
            "primaryContents", "sectionListRenderer", "contents"
        ) as? [[String: Any]] {
            let (sects, token) = self.parseSectionList(sectionContents)
            sections = sects
            continuationToken = token
        }
        // Continuation search (legacy)
        else if let contContents = json["continuationContents"] as? [String: Any],
                 let sectionList = contContents["sectionListContinuation"] as? [String: Any],
                 let contents = sectionList["contents"] as? [[String: Any]]
        {
            let (sects, token) = self.parseSectionList(contents)
            sections = sects
            continuationToken = token
        }
        // Modern continuation (search scrolling)
        else if let commands = (json["onResponseReceivedActions"] as? [[String: Any]]) ??
            (json["onResponseReceivedCommands"] as? [[String: Any]])
        {
            for command in commands {
                if let appendAction = command["appendContinuationItemsAction"] as? [String: Any],
                   let items = appendAction["continuationItems"] as? [[String: Any]]
                {
                    let (sects, token) = self.parseContinuationItems(items)
                    sections.append(contentsOf: sects)
                    if token != nil { continuationToken = token }
                }
            }
        }

        return YouTubeFeedResponse(sections: sections, continuationToken: continuationToken)
    }

    private static func parseContinuationItems(_ items: [[String: Any]]) -> ([YouTubeFeedSection], String?) {
        var sections: [YouTubeFeedSection] = []
        var continuationToken: String?
        var flatItems: [YouTubeFeedItem] = []

        for item in items {
            if let itemSection = item["itemSectionRenderer"] as? [String: Any] {
                let (sectItems, title) = self.parseItemSectionRenderer(itemSection)
                if !sectItems.isEmpty {
                    sections.append(YouTubeFeedSection(id: UUID().uuidString, title: title, items: sectItems))
                }
            } else if let shelf = item["shelfRenderer"] as? [String: Any] {
                let (sectItems, title) = self.parseShelfRenderer(shelf)
                if !sectItems.isEmpty {
                    sections.append(YouTubeFeedSection(id: UUID().uuidString, title: title, items: sectItems))
                }
            } else if let richItem = item["richItemRenderer"] as? [String: Any],
                      let content = richItem["content"] as? [String: Any],
                      let feedItem = self.parseRendererContent(content) {
                flatItems.append(feedItem)
            } else if let feedItem = self.parseRendererContent(item) {
                flatItems.append(feedItem)
            } else if let cont = item["continuationItemRenderer"] as? [String: Any] {
                continuationToken = self.extractContinuationToken(cont)
            }
        }

        if !flatItems.isEmpty {
            sections.append(YouTubeFeedSection(id: UUID().uuidString, title: nil, items: flatItems))
        }

        return (sections, continuationToken)
    }

    // MARK: - Section Parsing

    private static func parseTabs(_ tabs: [[String: Any]]) -> ([YouTubeFeedSection], String?) {
        var sections: [YouTubeFeedSection] = []
        var continuationToken: String?

        for tab in tabs {
            guard let tabRenderer = tab["tabRenderer"] as? [String: Any],
                  let content = tabRenderer["content"] as? [String: Any]
            else { continue }

            // Most explore/trending tabs use sectionListRenderer
            if let sectionList = content["sectionListRenderer"] as? [String: Any],
               let contents = sectionList["contents"] as? [[String: Any]]
            {
                let (sects, token) = self.parseSectionList(contents)
                sections.append(contentsOf: sects)
                if token != nil { continuationToken = token }
            }
            // Rich grid (e.g. library)
            else if let richGrid = content["richGridRenderer"] as? [String: Any],
                    let contents = richGrid["contents"] as? [[String: Any]]
            {
                let (items, token) = self.parseRichGridContents(contents)
                if token != nil { continuationToken = token }
                if !items.isEmpty {
                    sections.append(YouTubeFeedSection(id: UUID().uuidString, title: nil, items: items))
                }
            }
        }

        return (sections, continuationToken)
    }

    private static func parseSectionList(_ contents: [[String: Any]]) -> ([YouTubeFeedSection], String?) {
        var sections: [YouTubeFeedSection] = []
        var continuationToken: String?

        for item in contents {
            if let itemSection = item["itemSectionRenderer"] as? [String: Any] {
                let (items, title) = self.parseItemSectionRenderer(itemSection)
                if !items.isEmpty {
                    sections.append(YouTubeFeedSection(id: UUID().uuidString, title: title, items: items))
                }
            } else if let shelf = item["shelfRenderer"] as? [String: Any] {
                let (items, title) = self.parseShelfRenderer(shelf)
                if !items.isEmpty {
                    sections.append(YouTubeFeedSection(id: UUID().uuidString, title: title, items: items))
                }
            } else if let richSection = item["richSectionRenderer"] as? [String: Any],
                      let content = richSection["content"] as? [String: Any]
            {
                // Treat richSection content like a shelf
                if let richShelf = content["richShelfRenderer"] as? [String: Any] {
                    let title = self.extractText(richShelf["title"] as? [String: Any])
                    var items: [YouTubeFeedItem] = []
                    if let shelfContents = richShelf["contents"] as? [[String: Any]] {
                        for c in shelfContents {
                            if let richItem = c["richItemRenderer"] as? [String: Any],
                               let rendererContent = richItem["content"] as? [String: Any],
                               let feedItem = self.parseRendererContent(rendererContent)
                            {
                                items.append(feedItem)
                            }
                        }
                    }
                    if !items.isEmpty {
                        sections.append(YouTubeFeedSection(id: UUID().uuidString, title: title, items: items))
                    }
                }
            } else if let cont = item["continuationItemRenderer"] as? [String: Any] {
                continuationToken = self.extractContinuationToken(cont)
            }
        }

        return (sections, continuationToken)
    }

    private static func parseItemSectionRenderer(_ renderer: [String: Any]) -> ([YouTubeFeedItem], String?) {
        guard let contents = renderer["contents"] as? [[String: Any]] else { return ([], nil) }
        var items: [YouTubeFeedItem] = []
        var title: String?

        for entry in contents {
            if let feedItem = self.parseRendererContent(entry) {
                items.append(feedItem)
            }
            // Playlist pages (Watch Later, Liked, VL…) nest their videos
            // inside a playlistVideoListRenderer.
            else if let videoList = entry["playlistVideoListRenderer"] as? [String: Any],
                    let listContents = videoList["contents"] as? [[String: Any]]
            {
                for listEntry in listContents {
                    if let feedItem = self.parseRendererContent(listEntry) {
                        items.append(feedItem)
                    }
                }
            }
        }

        // Some itemSectionRenderers have a header
        if let header = renderer["header"] as? [String: Any],
           let itemSectionHeader = header["itemSectionHeaderRenderer"] as? [String: Any]
        {
            title = self.extractText(itemSectionHeader["title"] as? [String: Any])
        }

        return (items, title)
    }

    private static func parseShelfRenderer(_ shelf: [String: Any]) -> ([YouTubeFeedItem], String?) {
        let title = self.extractText(shelf["title"] as? [String: Any])
        var items: [YouTubeFeedItem] = []

        if let content = shelf["content"] as? [String: Any] {
            // Vertical list
            if let vertList = content["verticalListRenderer"] as? [String: Any],
               let listItems = vertList["items"] as? [[String: Any]]
            {
                for entry in listItems {
                    if let feedItem = self.parseRendererContent(entry) {
                        items.append(feedItem)
                    }
                }
            }
            // Horizontal / card list
            else if let hCardList = content["horizontalCardListRenderer"] as? [String: Any],
                    let cards = hCardList["cards"] as? [[String: Any]]
            {
                for card in cards {
                    if let feedItem = self.parseRendererContent(card) {
                        items.append(feedItem)
                    }
                }
            }
            // Expanded shelf items
            else if let expandedShelf = content["expandedShelfContentsRenderer"] as? [String: Any],
                    let shelfItems = expandedShelf["items"] as? [[String: Any]]
            {
                for entry in shelfItems {
                    if let feedItem = self.parseRendererContent(entry) {
                        items.append(feedItem)
                    }
                }
            }
        }

        return (items, title)
    }

    private static func parseRichGridContents(_ contents: [[String: Any]]) -> ([YouTubeFeedItem], String?) {
        var items: [YouTubeFeedItem] = []
        var continuationToken: String?

        for entry in contents {
            if let richItem = entry["richItemRenderer"] as? [String: Any],
               let content = richItem["content"] as? [String: Any],
               let feedItem = self.parseRendererContent(content)
            {
                items.append(feedItem)
            } else if let cont = entry["continuationItemRenderer"] as? [String: Any] {
                continuationToken = self.extractContinuationToken(cont)
            }
        }

        return (items, continuationToken)
    }

    // MARK: - Renderer Parsing

    private static func parseRendererContent(_ content: [String: Any]) -> YouTubeFeedItem? {
        if let r = content["lockupViewModel"] as? [String: Any] {
            // Lockups carry playlists too (e.g. FEplaylist_aggregation).
            if let contentType = r["contentType"] as? String,
               contentType.contains("PLAYLIST") || contentType.contains("PODCAST")
            {
                return self.parseLockupPlaylist(r).map { .playlist($0) }
            }
            return self.parseLockupViewModel(r).map { .video($0) }
        }
        if let r = content["playlistVideoRenderer"] as? [String: Any] {
            return self.parseVideoRenderer(r).map { .video($0) }
        }
        if let r = content["shortsLockupViewModel"] as? [String: Any] {
            return self.parseShortsLockupViewModel(r).map { .video($0) }
        }
        if let r = content["videoRenderer"] as? [String: Any] {
            return self.parseVideoRenderer(r).map { .video($0) }
        }
        if let r = content["compactVideoRenderer"] as? [String: Any] {
            return self.parseVideoRenderer(r).map { .video($0) }
        }
        if let r = content["gridVideoRenderer"] as? [String: Any] {
            return self.parseVideoRenderer(r).map { .video($0) }
        }
        if let r = content["reelItemRenderer"] as? [String: Any] {
            return self.parseReelItemRenderer(r).map { .video($0) }
        }
        if let r = content["playlistRenderer"] as? [String: Any] {
            return self.parsePlaylistRenderer(r).map { .playlist($0) }
        }
        if let r = content["gridPlaylistRenderer"] as? [String: Any] {
            return self.parsePlaylistRenderer(r).map { .playlist($0) }
        }
        if let r = content["channelRenderer"] as? [String: Any] {
            return self.parseChannelRenderer(r).map { .channel($0) }
        }
        if let r = content["gridChannelRenderer"] as? [String: Any] {
            return self.parseChannelRenderer(r).map { .channel($0) }
        }
        return nil
    }

    private static func parseLockupViewModel(_ dict: [String: Any]) -> YouTubeVideo? {
        guard let contentId = dict["contentId"] as? String else { return nil }

        // Music rows are often "mix" lockups whose contentId is a radio/mix id
        // (RDAMVM…), not a video id — loading that as a watch URL always fails.
        // Prefer the tap target's real videoId, and drop entries with none.
        var videoId = contentId
        if let rendererContext = dict["rendererContext"] as? [String: Any],
           let commandContext = rendererContext["commandContext"] as? [String: Any],
           let onTap = commandContext["onTap"] as? [String: Any],
           let command = onTap["innertubeCommand"] as? [String: Any],
           let watch = command["watchEndpoint"] as? [String: Any],
           let id = watch["videoId"] as? String, !id.isEmpty {
            videoId = id
        }
        guard videoId.count == 11 else { return nil }

        // Dig title
        var title = ""
        if let metadata = dict["metadata"] as? [String: Any],
           let lockupMetadata = metadata["lockupMetadataViewModel"] as? [String: Any],
           let titleDict = lockupMetadata["title"] as? [String: Any],
           let titleContent = titleDict["content"] as? String {
            title = titleContent
        }

        // Dig channel and metadata
        var channelName: String?
        var channelId: String?
        var viewCountText: String?
        var publishedText: String?

        if let metadata = dict["metadata"] as? [String: Any],
           let lockupMetadata = metadata["lockupMetadataViewModel"] as? [String: Any],
           let menuMetadata = lockupMetadata["metadata"] as? [String: Any],
           let contentMetadata = menuMetadata["contentMetadataViewModel"] as? [String: Any],
           let rows = contentMetadata["metadataRows"] as? [[String: Any]] {

            for row in rows {
                guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                for part in parts {
                    guard let textDict = part["text"] as? [String: Any],
                          let content = textDict["content"] as? String else { continue }

                    // Check if it's the channel name by looking for browseEndpoint (UC...)
                    if let runs = textDict["commandRuns"] as? [[String: Any]],
                       let firstRun = runs.first,
                       let onTap = firstRun["onTap"] as? [String: Any],
                       let cmd = onTap["innertubeCommand"] as? [String: Any],
                       let browse = cmd["browseEndpoint"] as? [String: Any],
                       let browseId = browse["browseId"] as? String,
                       browseId.hasPrefix("UC") {
                        channelName = content
                        channelId = browseId
                    } else if content.contains("view") {
                        viewCountText = content
                    } else if content.contains("ago") {
                        publishedText = content
                    }
                }
            }
        }

        // Dig thumbnail
        var thumbnailURL: URL?
        if let contentImage = dict["contentImage"] as? [String: Any],
           let thumbViewModel = contentImage["thumbnailViewModel"] as? [String: Any],
           let image = thumbViewModel["image"] as? [String: Any],
           let sources = image["sources"] as? [[String: Any]] {
            let sorted = sources.compactMap { t -> (Int, URL)? in
                guard let urlStr = t["url"] as? String, let url = self.normalizedURL(urlStr) else { return nil }
                let width = t["width"] as? Int ?? 0
                return (width, url)
            }.sorted { $0.0 > $1.0 }
            thumbnailURL = sorted.first?.1
        }

        // Dig duration overlay
        var lengthText: String?
        if let contentImage = dict["contentImage"] as? [String: Any],
           let thumbViewModel = contentImage["thumbnailViewModel"] as? [String: Any],
           let overlays = thumbViewModel["overlays"] as? [[String: Any]] {
            for overlay in overlays {
                if let bottomOverlay = overlay["thumbnailBottomOverlayViewModel"] as? [String: Any],
                   let badges = bottomOverlay["badges"] as? [[String: Any]],
                   let firstBadge = badges.first,
                   let badgeVM = firstBadge["thumbnailBadgeViewModel"] as? [String: Any],
                   let text = badgeVM["text"] as? String {
                    lengthText = text
                    break
                }
            }
        }

        return YouTubeVideo(
            videoId: videoId,
            title: title,
            channelName: channelName,
            channelId: channelId,
            lengthText: lengthText,
            viewCountText: viewCountText,
            publishedText: publishedText,
            thumbnailURL: thumbnailURL,
            isLive: false,
            isShort: false,
            watchedPercent: nil
        )
    }

    private static func parseLockupPlaylist(_ dict: [String: Any]) -> YouTubePlaylistItem? {
        guard let contentId = dict["contentId"] as? String else { return nil }

        var title = ""
        if let metadata = dict["metadata"] as? [String: Any],
           let lockupMetadata = metadata["lockupMetadataViewModel"] as? [String: Any],
           let titleDict = lockupMetadata["title"] as? [String: Any],
           let titleContent = titleDict["content"] as? String {
            title = titleContent
        }

        // Playlist lockups wrap their thumbnail in a collectionThumbnailViewModel.
        var thumbnailURL: URL?
        var videoCount: String?
        if let contentImage = dict["contentImage"] as? [String: Any] {
            let thumbViewModel = (contentImage["collectionThumbnailViewModel"] as? [String: Any])
                .flatMap { $0["primaryThumbnail"] as? [String: Any] }
                .flatMap { $0["thumbnailViewModel"] as? [String: Any] }
                ?? contentImage["thumbnailViewModel"] as? [String: Any]

            if let image = thumbViewModel?["image"] as? [String: Any],
               let sources = image["sources"] as? [[String: Any]] {
                let sorted = sources.compactMap { t -> (Int, URL)? in
                    guard let urlStr = t["url"] as? String, let url = self.normalizedURL(urlStr) else { return nil }
                    return (t["width"] as? Int ?? 0, url)
                }.sorted { $0.0 > $1.0 }
                thumbnailURL = sorted.first?.1
            }

            if let overlays = thumbViewModel?["overlays"] as? [[String: Any]] {
                for overlay in overlays {
                    if let bottomOverlay = overlay["thumbnailBottomOverlayViewModel"] as? [String: Any],
                       let badges = bottomOverlay["badges"] as? [[String: Any]],
                       let badgeVM = badges.first?["thumbnailBadgeViewModel"] as? [String: Any],
                       let text = badgeVM["text"] as? String {
                        videoCount = text
                        break
                    }
                }
            }
        }

        return YouTubePlaylistItem(
            playlistId: contentId,
            title: title,
            channelName: nil,
            thumbnailURL: thumbnailURL,
            videoCount: videoCount
        )
    }

    private static func parseShortsLockupViewModel(_ dict: [String: Any]) -> YouTubeVideo? {
        guard let onTap = dict["onTap"] as? [String: Any],
              let cmd = onTap["innertubeCommand"] as? [String: Any],
              let endpoint = cmd["reelWatchEndpoint"] as? [String: Any],
              let videoId = endpoint["videoId"] as? String else {
            return nil
        }

        var title = ""
        if let overlay = dict["overlayMetadata"] as? [String: Any],
           let primary = overlay["primaryText"] as? [String: Any],
           let content = primary["content"] as? String {
            title = content
        }

        var viewCountText: String?
        if let overlay = dict["overlayMetadata"] as? [String: Any],
           let secondary = overlay["secondaryText"] as? [String: Any],
           let content = secondary["content"] as? String {
            viewCountText = content
        }

        var thumbnailURL: URL?
        if let thumbVM = dict["thumbnailViewModel"] as? [String: Any],
           let subThumbVM = thumbVM["thumbnailViewModel"] as? [String: Any],
           let image = subThumbVM["image"] as? [String: Any],
           let sources = image["sources"] as? [[String: Any]] {
            let sorted = sources.compactMap { t -> (Int, URL)? in
                guard let urlStr = t["url"] as? String, let url = self.normalizedURL(urlStr) else { return nil }
                let width = t["width"] as? Int ?? 0
                return (width, url)
            }.sorted { $0.0 > $1.0 }
            thumbnailURL = sorted.first?.1
        }

        return YouTubeVideo(
            videoId: videoId,
            title: title,
            channelName: nil,
            channelId: nil,
            lengthText: nil,
            viewCountText: viewCountText,
            publishedText: nil,
            thumbnailURL: thumbnailURL,
            isLive: false,
            isShort: true,
            watchedPercent: nil
        )
    }

    private static func parseVideoRenderer(_ r: [String: Any]) -> YouTubeVideo? {
        guard let videoId = r["videoId"] as? String else { return nil }

        let title = self.extractText(r["title"] as? [String: Any]) ?? ""

        // Channel name — try ownerText, longBylineText, shortBylineText
        let channelName =
            self.extractText(r["ownerText"] as? [String: Any]) ??
            self.extractText(r["longBylineText"] as? [String: Any]) ??
            self.extractText(r["shortBylineText"] as? [String: Any])

        // Channel ID
        let channelId: String? = self.extractNavigationEndpointChannelId(
            r["ownerText"] as? [String: Any] ??
            r["longBylineText"] as? [String: Any] ??
            r["shortBylineText"] as? [String: Any]
        )

        // Thumbnail — take the highest-res available
        let thumbnailURL = self.extractBestThumbnail(r["thumbnail"] as? [String: Any])

        // Duration
        let lengthText = self.extractText(r["lengthText"] as? [String: Any])

        // Views
        let viewCountText =
            (r["viewCountText"] as? [String: Any]).flatMap { self.extractText($0) } ??
            (r["shortViewCountText"] as? [String: Any]).flatMap { self.extractText($0) }

        // Published date
        let publishedText = self.extractText(r["publishedTimeText"] as? [String: Any])

        // Badges
        let badges = self.extractBadges(r["badges"] as? [[String: Any]])
        let isLive = badges.contains("LIVE") ||
            (r["badges"] as? [[String: Any]])?.contains { badge in
                let label = ((badge["metadataBadgeRenderer"] as? [String: Any])?["label"] as? String) ?? ""
                return label.uppercased() == "LIVE NOW"
            } ?? false
        let isShort = (r["navigationEndpoint"] as? [String: Any]).flatMap {
            ($0["reelWatchEndpoint"] as? [String: Any])
        } != nil

        // Watched progress (0–100)
        var watchedPercent: Int?
        if let overlays = r["thumbnailOverlays"] as? [[String: Any]] {
            for overlay in overlays {
                if let resumeOverlay = overlay["thumbnailOverlayResumePlaybackRenderer"] as? [String: Any],
                   let percent = resumeOverlay["percentDurationWatched"] as? Int
                {
                    watchedPercent = percent
                    break
                }
            }
        }

        return YouTubeVideo(
            videoId: videoId,
            title: title,
            channelName: channelName,
            channelId: channelId,
            lengthText: lengthText,
            viewCountText: viewCountText,
            publishedText: publishedText,
            thumbnailURL: thumbnailURL,
            isLive: isLive,
            isShort: isShort,
            watchedPercent: watchedPercent
        )
    }

    private static func parseReelItemRenderer(_ r: [String: Any]) -> YouTubeVideo? {
        guard let videoId = r["videoId"] as? String else { return nil }
        let title = self.extractText(r["headline"] as? [String: Any]) ?? ""
        let thumbnailURL = self.extractBestThumbnail(r["thumbnail"] as? [String: Any])
        let viewCountText = self.extractText(r["viewCountText"] as? [String: Any])

        return YouTubeVideo(
            videoId: videoId,
            title: title,
            channelName: nil,
            channelId: nil,
            lengthText: nil,
            viewCountText: viewCountText,
            publishedText: nil,
            thumbnailURL: thumbnailURL,
            isLive: false,
            isShort: true,
            watchedPercent: nil
        )
    }

    private static func parsePlaylistRenderer(_ r: [String: Any]) -> YouTubePlaylistItem? {
        let playlistId = r["playlistId"] as? String ?? (r["navigationEndpoint"] as? [String: Any])
            .flatMap { $0["watchEndpoint"] as? [String: Any] }
            .flatMap { $0["playlistId"] as? String }
        guard let id = playlistId else { return nil }

        let title = self.extractText(r["title"] as? [String: Any]) ?? ""
        let channelName = self.extractText(r["longBylineText"] as? [String: Any]) ??
            self.extractText(r["shortBylineText"] as? [String: Any])
        let thumbnailURL = self.extractBestThumbnail(r["thumbnail"] as? [String: Any] ??
            r["thumbnails"] as? [String: Any])
        let videoCount = r["videoCount"] as? String

        return YouTubePlaylistItem(
            playlistId: id,
            title: title,
            channelName: channelName,
            thumbnailURL: thumbnailURL,
            videoCount: videoCount
        )
    }

    private static func parseChannelRenderer(_ r: [String: Any]) -> YouTubeChannelItem? {
        guard let channelId = r["channelId"] as? String else { return nil }
        let name = self.extractText(r["title"] as? [String: Any]) ?? ""
        let thumbnailURL = self.extractBestThumbnail(r["thumbnail"] as? [String: Any])
        let subscriberText = self.extractText(r["subscriberCountText"] as? [String: Any])
        let videoCountText = self.extractText(r["videoCountText"] as? [String: Any])

        return YouTubeChannelItem(
            channelId: channelId,
            name: name,
            thumbnailURL: thumbnailURL,
            subscriberCountText: subscriberText,
            videoCountText: videoCountText
        )
    }

    // MARK: - Helpers

    /// Extracts plain text from a runs/simpleText structure.
    static func extractText(_ dict: [String: Any]?) -> String? {
        guard let dict else { return nil }
        if let simple = dict["simpleText"] as? String { return simple }
        if let runs = dict["runs"] as? [[String: Any]] {
            return runs.compactMap { $0["text"] as? String }.joined()
        }
        return nil
    }

    /// Builds a loadable URL, fixing YouTube's scheme-relative forms ("//yt3…").
    private static func normalizedURL(_ string: String) -> URL? {
        if string.hasPrefix("//") {
            return URL(string: "https:" + string)
        }
        return URL(string: string)
    }

    private static func extractBestThumbnail(_ dict: [String: Any]?) -> URL? {
        guard let dict,
              let thumbnails = dict["thumbnails"] as? [[String: Any]]
        else { return nil }

        // Sort by width descending, take largest
        let sorted = thumbnails.compactMap { t -> (Int, URL)? in
            guard let urlStr = t["url"] as? String, let url = self.normalizedURL(urlStr) else { return nil }
            let width = t["width"] as? Int ?? 0
            return (width, url)
        }.sorted { $0.0 > $1.0 }

        return sorted.first?.1
    }

    private static func extractBadges(_ badges: [[String: Any]]?) -> Set<String> {
        guard let badges else { return [] }
        var result = Set<String>()
        for badge in badges {
            if let metaBadge = badge["metadataBadgeRenderer"] as? [String: Any],
               let style = metaBadge["style"] as? String
            {
                result.insert(style)
            }
        }
        return result
    }

    private static func extractNavigationEndpointChannelId(_ dict: [String: Any]?) -> String? {
        guard let dict, let runs = dict["runs"] as? [[String: Any]] else { return nil }
        for run in runs {
            if let nav = run["navigationEndpoint"] as? [String: Any],
               let browseEndpoint = nav["browseEndpoint"] as? [String: Any],
               let channelId = browseEndpoint["browseId"] as? String
            {
                return channelId
            }
        }
        return nil
    }

    private static func extractContinuationToken(_ renderer: [String: Any]) -> String? {
        // continuationItemRenderer → triggerOnScrollIntoView.continuationEndpoint
        // or continuationEndpoint directly
        if let endpoint = renderer["continuationEndpoint"] as? [String: Any],
           let command = endpoint["continuationCommand"] as? [String: Any],
           let token = command["token"] as? String
        {
            return token
        }
        if let trigger = renderer["triggerOnScrollIntoView"] as? [String: Any],
           let endpoint = trigger["continuationEndpoint"] as? [String: Any],
           let command = endpoint["continuationCommand"] as? [String: Any],
           let token = command["token"] as? String
        {
            return token
        }
        return nil
    }

    /// Dig nested dictionary by a sequence of string keys.
    private static func dig(_ dict: [String: Any], _ keys: String...) -> Any? {
        var current: Any = dict
        for key in keys {
            guard let d = current as? [String: Any], let next = d[key] else { return nil }
            current = next
        }
        return current
    }
}

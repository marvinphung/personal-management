import Foundation
import WidgetKit

public struct InboxEntry: TimelineEntry {
    public let date: Date
    public let count: Int
    public let isLoggedIn: Bool
    public let isOffline: Bool

    public init(date: Date, count: Int, isLoggedIn: Bool, isOffline: Bool) {
        self.date = date
        self.count = count
        self.isLoggedIn = isLoggedIn
        self.isOffline = isOffline
    }

    public static var placeholder: InboxEntry {
        InboxEntry(date: Date(), count: 0, isLoggedIn: true, isOffline: false)
    }
}

public struct InboxTimelineProvider: TimelineProvider {
    public typealias Entry = InboxEntry

    public init() {}

    public func placeholder(in context: Context) -> InboxEntry {
        InboxEntry.placeholder
    }

    public func getSnapshot(in context: Context, completion: @escaping (InboxEntry) -> Void) {
        let creds = WidgetCache.shared.getWidgetCredentials()
        let count = WidgetCache.shared.getPendingCount()
        let entry = InboxEntry(
            date: Date(),
            count: count,
            isLoggedIn: creds != nil,
            isOffline: false
        )
        completion(entry)
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<InboxEntry>) -> Void) {
        let currentDate = Date()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)

        guard let creds = WidgetCache.shared.getWidgetCredentials() else {
            let entry = InboxEntry(date: currentDate, count: 0, isLoggedIn: false, isOffline: false)
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
            return
        }

        WidgetAPI.shared.fetchSummary(baseUrl: creds.baseUrl, token: creds.token) { result in
            let entry: InboxEntry
            switch result {
            case .success(let summary):
                entry = InboxEntry(date: currentDate, count: summary.pendingCount, isLoggedIn: true, isOffline: false)
            case .failure:
                let cachedCount = WidgetCache.shared.getPendingCount()
                entry = InboxEntry(date: currentDate, count: cachedCount, isLoggedIn: true, isOffline: true)
            }
            let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
            completion(timeline)
        }
    }
}

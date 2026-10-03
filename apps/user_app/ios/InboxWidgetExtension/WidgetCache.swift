import Foundation

public final class WidgetCache {
    public static let shared = WidgetCache()
    public static let appGroupId = "group.app.quanlytao.user"

    private let userDefaults: UserDefaults?

    public init(suiteName: String = appGroupId) {
        self.userDefaults = UserDefaults(suiteName: suiteName)
    }

    public enum Keys {
        public static let pendingCount = "pending_count"
        public static let widgetToken = "widget_token"
        public static let baseUrl = "base_url"
        public static let lastUpdated = "last_updated_epoch_ms"
        public static let lastError = "last_error"
    }

    public func getPendingCount() -> Int {
        return userDefaults?.integer(forKey: Keys.pendingCount) ?? 0
    }

    public func setPendingCount(_ count: Int) {
        userDefaults?.set(max(0, count), forKey: Keys.pendingCount)
        userDefaults?.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: Keys.lastUpdated)
    }

    public func getWidgetCredentials() -> (token: String, baseUrl: String)? {
        guard let token = userDefaults?.string(forKey: Keys.widgetToken), !token.isEmpty,
              let baseUrl = userDefaults?.string(forKey: Keys.baseUrl), !baseUrl.isEmpty else {
            return nil
        }
        return (token: token, baseUrl: baseUrl)
    }

    public func setWidgetCredentials(token: String, baseUrl: String) {
        userDefaults?.set(token, forKey: Keys.widgetToken)
        userDefaults?.set(baseUrl, forKey: Keys.baseUrl)
        userDefaults?.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: Keys.lastUpdated)
    }

    public func clear() {
        userDefaults?.removeObject(forKey: Keys.pendingCount)
        userDefaults?.removeObject(forKey: Keys.widgetToken)
        userDefaults?.removeObject(forKey: Keys.baseUrl)
        userDefaults?.removeObject(forKey: Keys.lastUpdated)
        userDefaults?.removeObject(forKey: Keys.lastError)
    }

    public func setLastError(_ error: String?) {
        if let error = error {
            userDefaults?.set(error, forKey: Keys.lastError)
        } else {
            userDefaults?.removeObject(forKey: Keys.lastError)
        }
    }

    public func getLastError() -> String? {
        return userDefaults?.string(forKey: Keys.lastError)
    }
}

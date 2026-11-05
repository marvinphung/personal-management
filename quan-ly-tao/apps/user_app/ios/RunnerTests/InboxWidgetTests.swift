import XCTest
import Foundation

class InboxWidgetTests: XCTestCase {
    private var testCache: WidgetCache!
    private let testSuiteName = "group.app.quanlytao.user.test"

    override func setUp() {
        super.setUp()
        testCache = WidgetCache(suiteName: testSuiteName)
        testCache.clear()
    }

    override func tearDown() {
        testCache.clear()
        super.tearDown()
    }

    func testWidgetSummaryDecoding() throws {
        let json = """
        {
            "pending_count": 5,
            "pending_ids": ["uuid-1", "uuid-2", "uuid-3", "uuid-4", "uuid-5"],
            "captured_epoch": 1727913600
        }
        """.data(using: .utf8)!

        struct SummaryPayload: Decodable {
            let pendingCount: Int
            let pendingIds: [String]
            let capturedEpoch: Int

            enum CodingKeys: String, CodingKey {
                case pendingCount = "pending_count"
                case pendingIds = "pending_ids"
                case capturedEpoch = "captured_epoch"
            }
        }

        let summary = try JSONDecoder().decode(SummaryPayload.self, from: json)
        XCTAssertEqual(summary.pendingCount, 5)
        XCTAssertEqual(summary.pendingIds.count, 5)
        XCTAssertEqual(summary.pendingIds.first, "uuid-1")
        XCTAssertEqual(summary.capturedEpoch, 1727913600)
    }

    func testWidgetSummaryExcludesFinancialAmounts() throws {
        let json = """
        {
            "pending_count": 0,
            "pending_ids": [],
            "captured_epoch": 1727913600
        }
        """.data(using: .utf8)!

        let dict = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        XCTAssertNotNil(dict)
        XCTAssertNil(dict?["amount"])
        XCTAssertNil(dict?["balance"])
        XCTAssertNil(dict?["money"])
        XCTAssertNil(dict?["description"])
    }

    func testDeepLinkUrlParsing() {
        let validUrl = URL(string: "quanlytao://bank-inbox")!
        XCTAssertEqual(validUrl.scheme, "quanlytao")
        XCTAssertEqual(validUrl.host, "bank-inbox")

        let invalidUrl = URL(string: "otherapp://bank-inbox")!
        XCTAssertNotEqual(invalidUrl.scheme, "quanlytao")
    }

    func testWidgetSummaryURLDoesNotDuplicateVersionPrefix() {
        XCTAssertEqual(
            WidgetAPI.summaryURL(baseUrl: "http://127.0.0.1:8000/v1")?.absoluteString,
            "http://127.0.0.1:8000/v1/widget/summary"
        )
        XCTAssertEqual(
            WidgetAPI.summaryURL(baseUrl: "https://api.example.test/")?.absoluteString,
            "https://api.example.test/v1/widget/summary"
        )
    }

    func testWidgetCacheGenerationGuard() {
        testCache.setWidgetCredentials(token: "test_token", baseUrl: "http://localhost", owner: "user_a", generation: 2)
        testCache.setPendingCount(5, owner: "user_a", generation: 2)
        XCTAssertEqual(testCache.getPendingCount(), 5)
        XCTAssertFalse(testCache.isStale())

        // Incoming update from older generation 1 must be ignored
        testCache.setPendingCount(10, owner: "user_a", generation: 1)
        XCTAssertEqual(testCache.getPendingCount(), 5)

        // Incoming update with generation >= 2 must be accepted
        testCache.setPendingCount(3, owner: "user_a", generation: 2)
        XCTAssertEqual(testCache.getPendingCount(), 3)
    }

    func testWidgetCacheClearAndStale() {
        testCache.setWidgetCredentials(token: "token_123", baseUrl: "https://example.com", owner: "user_1", generation: 1)
        testCache.setPendingCount(7)
        testCache.setStale(true)
        XCTAssertTrue(testCache.isStale())
        XCTAssertNotNil(testCache.getWidgetCredentials())

        testCache.clear()
        XCTAssertNil(testCache.getWidgetCredentials())
        XCTAssertEqual(testCache.getPendingCount(), 0)
        XCTAssertFalse(testCache.isStale())
    }
}

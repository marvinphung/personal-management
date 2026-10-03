import XCTest
import Foundation

class InboxWidgetTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
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

        let summary = try JSONDecoder().decode(SummaryPayload, from: json)
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
}

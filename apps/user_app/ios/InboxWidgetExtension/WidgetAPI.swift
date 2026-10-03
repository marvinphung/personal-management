import Foundation

public struct WidgetSummary: Decodable {
    public let pendingCount: Int
    public let pendingIds: [String]
    public let capturedEpoch: Int

    enum CodingKeys: String, CodingKey {
        case pendingCount = "pending_count"
        case pendingIds = "pending_ids"
        case capturedEpoch = "captured_epoch"
    }
}

public final class WidgetAPI {
    public static let shared = WidgetAPI()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchSummary(baseUrl: String, token: String, completion: @escaping (Result<WidgetSummary, Error>) -> Void) {
        guard let url = URL(string: "\(baseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/v1/widget/summary") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                // Widget credentials invalid or revoked
                WidgetCache.shared.clear()
                completion(.failure(NSError(domain: "app.quanlytao.widget", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Authentication required"])))
                return
            }

            guard (200...299).contains(httpResponse.statusCode), let data = data else {
                completion(.failure(NSError(domain: "app.quanlytao.widget", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])))
                return
            }

            do {
                let summary = try JSONDecoder().decode(WidgetSummary, from: data)
                WidgetCache.shared.setPendingCount(summary.pendingCount)
                WidgetCache.shared.setLastError(nil)
                completion(.success(summary))
            } catch {
                WidgetCache.shared.setLastError("JSON decode error")
                completion(.failure(error))
            }
        }
        task.resume()
    }
}

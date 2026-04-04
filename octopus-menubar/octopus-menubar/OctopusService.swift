import Foundation

enum OctopusError: LocalizedError {
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "API error (HTTP \(code))"
        }
    }
}

actor OctopusService {
    static let shared = OctopusService()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func fetchSlots(region: Region, date: Date) async throws -> [PriceSlot] {
        let url = buildURL(region: region, date: date)
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw OctopusError.badStatus(http.statusCode)
        }
        let envelope = try decoder.decode(OctopusResponse.self, from: data)
        // API returns newest-first; reverse for chronological order
        return envelope.results.reversed()
    }

    private func buildURL(region: Region, date: Date) -> URL {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]

        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.octopus.energy"
        components.path = "/v1/products/AGILE-24-10-01/electricity-tariffs/\(region.tariffCode)/standard-unit-rates/"
        components.queryItems = [
            URLQueryItem(name: "period_from", value: fmt.string(from: startOfDay)),
            URLQueryItem(name: "period_to",   value: fmt.string(from: endOfDay))
        ]
        return components.url!
    }
}

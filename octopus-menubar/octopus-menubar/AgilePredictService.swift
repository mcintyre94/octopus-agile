import Foundation

// MARK: - Models

/// A half-hour slot of predicted price from AgilePredict.
///
/// `low`/`high` are the p10/p90 uncertainty band. They're nil for a slot whose
/// prediction has been replaced by a confirmed Octopus price, which is what
/// `isConfirmed` marks.
struct ForecastSlot: Identifiable {
    var id: Date { validFrom }
    let validFrom: Date
    let validTo: Date
    let price: Double
    let low: Double?
    let high: Double?
    let isConfirmed: Bool
}

/// One forecast run: every prediction from a single AgilePredict model pass.
struct Forecast {
    /// When AgilePredict ran the model. Runs land every few hours.
    let createdAt: Date
    let slots: [ForecastSlot]
}

// MARK: - Shaping

extension Forecast {
    /// Swaps in the confirmed Octopus price wherever we already have one, so
    /// today (and tomorrow once published) read as fact rather than forecast.
    ///
    /// AgilePredict's own near-term numbers track the published prices closely
    /// but not exactly, so preferring Octopus keeps the 7-day view consistent
    /// with the Today and Tomorrow tabs.
    func merging(confirmed: [PriceSlot]) -> Forecast {
        guard !confirmed.isEmpty else { return self }
        let prices = Dictionary(
            confirmed.map { ($0.validFrom, $0.valueIncVat) },
            uniquingKeysWith: { first, _ in first }
        )
        return Forecast(createdAt: createdAt, slots: slots.map { slot in
            guard let price = prices[slot.validFrom] else { return slot }
            return ForecastSlot(
                validFrom: slot.validFrom,
                validTo: slot.validTo,
                price: price,
                low: nil,
                high: nil,
                isConfirmed: true
            )
        })
    }

    /// Drops slots that have already finished. A forecast run is published on
    /// the hour and covers the slot it was made in, so the first slot or two
    /// are usually in the past by the time we read it.
    func trimmed(to now: Date) -> Forecast {
        Forecast(createdAt: createdAt, slots: slots.filter { $0.validTo > now })
    }

    /// Slots grouped into calendar days, in order. The first day is normally
    /// partial, since the forecast starts at the slot in progress.
    var days: [ForecastDay] {
        let calendar = Calendar.current
        var days: [ForecastDay] = []
        for slot in slots {
            let start = calendar.startOfDay(for: slot.validFrom)
            if days.last?.start == start {
                days[days.count - 1].slots.append(slot)
            } else {
                days.append(ForecastDay(start: start, slots: [slot]))
            }
        }
        return days
    }
}

/// A calendar day's worth of forecast slots, with the numbers worth showing
/// for a day you can't see slot by slot.
struct ForecastDay: Identifiable {
    let start: Date
    var slots: [ForecastSlot]

    var id: Date { start }

    /// True when the day's figures are fact rather than forecast.
    ///
    /// Deliberately a majority rather than every slot: Octopus publishes in
    /// batches running to 23:00, so a day's last hour only lands at about 4pm
    /// that afternoon. Requiring every slot would leave today marked as a
    /// prediction all morning, when 46 of its 48 prices are published.
    var isConfirmed: Bool {
        guard !slots.isEmpty else { return false }
        let confirmed = slots.reduce(0) { $0 + ($1.isConfirmed ? 1 : 0) }
        return confirmed * 2 > slots.count
    }

    /// True when the day isn't covered midnight to midnight. The window runs
    /// 7 days from the slot in progress, so it clips both the first calendar
    /// day and the last — and a day that only reaches mid-morning averages
    /// far cheaper than it would whole.
    var isPartial: Bool { slots.count < 48 }

    var cheapest: ForecastSlot? { slots.min { $0.price < $1.price } }
    var peak: ForecastSlot? { slots.max { $0.price < $1.price } }

    var average: Double {
        guard !slots.isEmpty else { return 0 }
        return slots.reduce(0) { $0 + $1.price } / Double(slots.count)
    }
}

extension Array where Element == ForecastSlot {
    /// Indices at which the calendar day changes, for drawing day separators.
    /// Never includes 0, which is the left edge of the chart rather than a break.
    var dayBoundaryIndices: [Int] {
        let calendar = Calendar.current
        return indices.filter { index in
            guard index > 0 else { return false }
            return !calendar.isDate(self[index].validFrom, inSameDayAs: self[index - 1].validFrom)
        }
    }

    /// First index of each calendar day wide enough to be labelled. Day labels
    /// hang off these left-aligned, so each one needs its own day's width to
    /// sit in before the next label starts.
    ///
    /// The window runs 7 days from the slot in progress, so it opens and
    /// closes part-way through a day — and those two stub days are the ones
    /// that can't hold a label.
    var dayStartIndices: [Int] {
        guard !isEmpty else { return [] }
        let boundaries = dayBoundaryIndices
        let starts = [0] + boundaries
        let ends = boundaries + [count]
        // A weekday abbreviation needs roughly a tenth of the plot width.
        let minimumSlots = Swift.max(4, count / 10)
        return zip(starts, ends).compactMap { start, end in
            end - start >= minimumSlots ? start : nil
        }
    }

    /// Y range wide enough for the uncertainty band, not just the predictions.
    var valueDomain: ClosedRange<Double> {
        let lows = map { $0.low ?? $0.price }
        let highs = map { $0.high ?? $0.price }
        return Swift.min(lows.min() ?? 0, 0)...Swift.max(highs.max() ?? 40, 5)
    }
}

// MARK: - Service

enum AgilePredictError: LocalizedError {
    case badStatus(Int)
    case noForecast

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "AgilePredict error (HTTP \(code))"
        case .noForecast:          return "No forecast available for this region."
        }
    }
}

/// Fetches price predictions from [AgilePredict](https://agilepredict.com).
///
/// The API is public and unauthenticated but rate-limited, so we ask for one
/// forecast run at a time and let the callers cache what they get.
actor AgilePredictService {
    static let shared = AgilePredictService()

    /// How far ahead we ask for. The API allows up to 14 days.
    private static let forecastDays = 7

    /// How long a fetched run stays good for. AgilePredict publishes a new run
    /// every few hours, so re-asking sooner can only return what we already
    /// have — and the menubar panel calls refresh every time it's opened.
    private static let cacheLifetime: TimeInterval = 30 * 60

    private var cache: [Region: (forecast: Forecast, fetchedAt: Date)] = [:]

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // Slot times come without fractional seconds, `created_at` with them.
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        d.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = plain.date(from: text) ?? withFraction.date(from: text) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Bad date: \(text)")
                )
            }
            return date
        }
        return d
    }()

    func fetchForecast(region: Region) async throws -> Forecast {
        if let cached = cache[region], Date().timeIntervalSince(cached.fetchedAt) < Self.cacheLifetime {
            return cached.forecast
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "agilepredict.com"
        // The trailing slash matters: without it the API answers with a redirect.
        components.path = "/api/\(region.rawValue)/"
        components.queryItems = [URLQueryItem(name: "days", value: String(Self.forecastDays))]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw AgilePredictError.badStatus(http.statusCode)
        }

        // The endpoint answers with a list of runs, newest first. An unknown
        // region still returns 200, with an empty price list.
        let runs = try decoder.decode([AgilePredictRun].self, from: data)
        guard let run = runs.first, !run.prices.isEmpty else {
            throw AgilePredictError.noForecast
        }

        let slots = run.prices.map { price in
            ForecastSlot(
                validFrom: price.dateTime,
                validTo: price.dateTime.addingTimeInterval(30 * 60),
                price: price.agilePred,
                low: price.agileLow,
                high: price.agileHigh,
                isConfirmed: false
            )
        }
        let forecast = Forecast(createdAt: run.createdAt, slots: slots.sorted { $0.validFrom < $1.validFrom })
        cache[region] = (forecast, Date())
        return forecast
    }
}

// MARK: - Wire format

private struct AgilePredictRun: Decodable {
    let createdAt: Date
    let prices: [AgilePredictPrice]
}

private struct AgilePredictPrice: Decodable {
    let dateTime: Date
    let agilePred: Double
    let agileLow: Double?
    let agileHigh: Double?
}

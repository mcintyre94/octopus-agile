import SwiftUI

// MARK: - API Models

struct PriceSlot: Identifiable, Decodable {
    var id: String { validFrom.ISO8601Format() }
    let valueIncVat: Double
    let validFrom: Date
    let validTo: Date


}

struct OctopusResponse: Decodable {
    let count: Int
    let results: [PriceSlot]
}

// MARK: - Region

enum Region: String, CaseIterable, Identifiable {
    case a = "A", b = "B", c = "C", d = "D", e = "E",
         f = "F", g = "G", h = "H", j = "J", k = "K",
         l = "L", m = "M", n = "N", p = "P"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a: return "A – Eastern England"
        case .b: return "B – East Midlands"
        case .c: return "C – London"
        case .d: return "D – Merseyside & N. Wales"
        case .e: return "E – Midlands"
        case .f: return "F – North Eastern"
        case .g: return "G – North Western"
        case .h: return "H – Southern England"
        case .j: return "J – South Eastern"
        case .k: return "K – South Western"
        case .l: return "L – South Wales"
        case .m: return "M – Yorkshire"
        case .n: return "N – Southern Scotland"
        case .p: return "P – Northern Scotland"
        }
    }

    var shortName: String {
        displayName.components(separatedBy: " – ").last ?? displayName
    }

    var tariffCode: String {
        "E-1R-AGILE-24-10-01-\(rawValue)"
    }
}

// MARK: - Price Category

enum PriceCategory {
    case negative, low, medium, high

    /// Band boundaries in p/kWh inc. VAT.
    static let lowThreshold  = 15.0
    static let highThreshold = 30.0

    static func from(_ pence: Double) -> PriceCategory {
        if pence < 0              { return .negative }
        if pence < lowThreshold   { return .low }
        if pence < highThreshold  { return .medium }
        return .high
    }

    var color: Color {
        switch self {
        case .negative: return .blue
        case .low:      return .green
        case .medium:   return .orange
        case .high:     return .red
        }
    }

    /// A bottom-to-top gradient over a price axis, with hard stops where the
    /// bands change. Lets a single line carry the same colour coding the bars
    /// use, instead of being split into one series per band.
    static func gradient(over domain: ClosedRange<Double>) -> LinearGradient {
        let span = domain.upperBound - domain.lowerBound
        func location(_ price: Double) -> Double {
            guard span > 0 else { return 0 }
            return min(max((price - domain.lowerBound) / span, 0), 1)
        }
        return LinearGradient(
            stops: [
                .init(color: PriceCategory.negative.color, location: 0),
                .init(color: PriceCategory.negative.color, location: location(0)),
                .init(color: PriceCategory.low.color,      location: location(0)),
                .init(color: PriceCategory.low.color,      location: location(lowThreshold)),
                .init(color: PriceCategory.medium.color,   location: location(lowThreshold)),
                .init(color: PriceCategory.medium.color,   location: location(highThreshold)),
                .init(color: PriceCategory.high.color,     location: location(highThreshold)),
                .init(color: PriceCategory.high.color,     location: 1)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

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

    var tariffCode: String {
        "E-1R-AGILE-24-10-01-\(rawValue)"
    }
}

// MARK: - Price Category

enum PriceCategory {
    case negative, low, medium, high

    static func from(_ pence: Double) -> PriceCategory {
        if pence < 0  { return .negative }
        if pence < 15 { return .low }
        if pence < 30 { return .medium }
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
}

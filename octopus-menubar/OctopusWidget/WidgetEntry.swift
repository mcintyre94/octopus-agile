import Foundation
import WidgetKit

struct PriceEntry: TimelineEntry {
    /// When WidgetKit should start rendering this entry.
    let date: Date
    /// The slots on show. Until tomorrow's prices are published this is today,
    /// midnight to midnight. After that it's the slot in progress through to the
    /// end of tomorrow, which is the more useful window in the evening.
    let slots: [PriceSlot]
    /// Index of the active slot at `date`.
    let currentIndex: Int
    /// Index of the first slot falling on the day after the window starts, when
    /// the window runs past midnight.
    let tomorrowStartIndex: Int?
    let region: Region
    let errorMessage: String?

    static let placeholder = PriceEntry(
        date: Date(),
        slots: [],
        currentIndex: 0,
        tomorrowStartIndex: nil,
        region: .c,
        errorMessage: nil
    )

    var currentSlot: PriceSlot? {
        guard slots.indices.contains(currentIndex) else { return nil }
        return slots[currentIndex]
    }

    /// Index the upcoming-slot lists start from.
    var upcomingStart: Int { min(currentIndex + 1, slots.count) }

    func upcomingSlots(limit: Int) -> [PriceSlot] {
        Array(slots[upcomingStart...].prefix(limit))
    }

    /// Slots sitting on a 4-hour boundary, so x-axis labels read as whole hours
    /// even when the window starts partway through the day.
    var axisIndices: [Int] {
        let calendar = Calendar.current
        let onTheHour = slots.indices.filter {
            let parts = calendar.dateComponents([.hour, .minute], from: slots[$0].validFrom)
            return parts.minute == 0 && (parts.hour ?? 0) % 4 == 0
        }
        return onTheHour.isEmpty ? stride(from: 0, to: slots.count, by: 8).map { $0 } : onTheHour
    }

    var yDomain: ClosedRange<Double> {
        let prices = slots.map(\.valueIncVat)
        return min(prices.min() ?? 0, 0)...max(prices.max() ?? 40, 5)
    }
}

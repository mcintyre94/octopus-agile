import Foundation
import WidgetKit

/// A week of AgilePredict predictions, with confirmed Octopus prices folded in
/// for the days we already know.
struct ForecastEntry: TimelineEntry {
    /// When WidgetKit should start rendering this entry.
    let date: Date
    let slots: [ForecastSlot]
    /// `slots` grouped by calendar day, derived once here rather than on every
    /// pass through a view body.
    let days: [ForecastDay]
    /// When AgilePredict ran the model, if we have a forecast at all.
    let createdAt: Date?
    let region: Region
    let errorMessage: String?

    init(date: Date, forecast: Forecast?, region: Region, errorMessage: String? = nil) {
        self.date = date
        self.slots = forecast?.slots ?? []
        self.days = forecast?.days ?? []
        self.createdAt = forecast.map(\.createdAt)
        self.region = region
        self.errorMessage = errorMessage
    }

    static let placeholder = ForecastEntry(date: Date(), forecast: nil, region: .c)

    /// The p10–p90 ribbon, which only covers the predicted part of the window.
    var band: [(index: Int, low: Double, high: Double)] {
        slots.enumerated().compactMap { index, slot in
            guard let low = slot.low, let high = slot.high else { return nil }
            return (index, low, high)
        }
    }

    /// Days a whole-day average can fairly be compared across. The window's
    /// first and last calendar days are clipped, so they'd win or lose on
    /// which hours they happen to contain.
    var comparableDays: [ForecastDay] {
        let whole = days.filter { !$0.isPartial }
        return whole.isEmpty ? days : whole
    }

    /// The cheapest day to plan around, by average price.
    var cheapestDay: ForecastDay? {
        comparableDays.min { $0.average < $1.average }
    }
}

import SwiftUI
import Charts
import WidgetKit

// MARK: - Entry View (dispatches by size)

struct ForecastWidgetEntryView: View {
    let entry: ForecastEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallForecastView(entry: entry)
        case .systemMedium:
            MediumForecastView(entry: entry)
        default:
            LargeForecastView(entry: entry)
        }
    }
}

// MARK: - Formatters

private let weekdayFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEE"; f.timeZone = .current; return f
}()

private let slotTimeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
}()

/// "Today"/"Tomorrow" where that reads better than a weekday.
private func shortDayLabel(_ start: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(start) { return "Today" }
    if calendar.isDateInTomorrow(start) { return "Tmrw" }
    return weekdayFormatter.string(from: start)
}

// MARK: - Shared chart

/// The week at a glance: colour-coded half-hour bars with the p10–p90 ribbon
/// behind the part that's still a prediction.
private struct ForecastSkyline: View {
    let entry: ForecastEntry
    let showYAxis: Bool

    var body: some View {
        Chart {
            ForEach(entry.band, id: \.index) { point in
                AreaMark(
                    x: .value("Slot", point.index),
                    yStart: .value("Low", point.low),
                    yEnd: .value("High", point.high)
                )
                .foregroundStyle(Color.secondary.opacity(0.22))
            }

            // Bars would be a fraction of a point wide across a week and
            // would bury the band; the gradient keeps the colour coding.
            ForEach(Array(entry.slots.enumerated()), id: \.offset) { index, slot in
                LineMark(
                    x: .value("Slot", index),
                    y: .value("p", slot.price)
                )
            }
            .foregroundStyle(PriceCategory.gradient(over: entry.slots.valueDomain))
            .lineStyle(StrokeStyle(lineWidth: 1.2))

            ForEach(entry.slots.dayBoundaryIndices, id: \.self) { boundary in
                RuleMark(x: .value("Day", boundary))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }
        }
        .chartXScale(domain: -0.5...(Double(entry.slots.count) - 0.5))
        .chartXAxis {
            // Left-aligned off each day's first slot: a centred label on the
            // part-day at either end overflows the plot.
            AxisMarks(values: entry.slots.dayStartIndices) { value in
                AxisValueLabel(anchor: .topLeading) {
                    if let i = value.as(Int.self), i < entry.slots.count {
                        Text(shortDayLabel(entry.slots[i].validFrom))
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .chartYScale(domain: entry.slots.valueDomain)
        .chartYAxis {
            if showYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text("\(v, format: .number.precision(.fractionLength(0)))p")
                                .font(.system(size: 9))
                        }
                    }
                }
            }
        }
    }
}

private struct ForecastHeader: View {
    let entry: ForecastEntry
    let size: CGFloat

    var body: some View {
        HStack {
            Text(entry.region.shortName)
                .font(.system(size: size))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text("7-day forecast")
                .font(.system(size: size))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct ForecastUnavailable: View {
    let message: String?

    var body: some View {
        VStack {
            Spacer()
            Text(message ?? "Forecast not available")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Spacer()
        }
    }
}

// MARK: - Small

/// Too narrow for a week of half-hour bars, so it answers the one question a
/// 7-day forecast is for: which day to wait for.
struct SmallForecastView: View {
    let entry: ForecastEntry

    private var days: [ForecastDay] { entry.comparableDays }

    private var averageDomain: ClosedRange<Double> {
        let averages = days.map(\.average)
        return min(averages.min() ?? 0, 0)...max(averages.max() ?? 30, 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.region.shortName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if entry.slots.isEmpty {
                ForecastUnavailable(message: entry.errorMessage)
            } else if let cheapest = entry.cheapestDay {
                Text("Cheapest")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(shortDayLabel(cheapest.start))
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(PriceCategory.from(cheapest.average).color)
                Text(String(format: "%.1fp avg", cheapest.average))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // One bar per day, so the shape of the week is still visible.
                Chart {
                    ForEach(days) { day in
                        BarMark(
                            x: .value("Day", day.start, unit: .day),
                            y: .value("p", day.average)
                        )
                        .foregroundStyle(
                            PriceCategory.from(day.average).color
                                .opacity(day.id == cheapest.id ? 1.0 : 0.45)
                        )
                        .cornerRadius(1)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: averageDomain)
                .frame(minHeight: 28, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium

struct MediumForecastView: View {
    let entry: ForecastEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.region.shortName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let cheapest = entry.cheapestDay {
                    Text(String(format: "Cheapest: %@ %.1fp", shortDayLabel(cheapest.start), cheapest.average))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(PriceCategory.from(cheapest.average).color)
                }
            }

            if entry.slots.isEmpty {
                ForecastUnavailable(message: entry.errorMessage)
            } else {
                ForecastSkyline(entry: entry, showYAxis: false)
                    .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large

struct LargeForecastView: View {
    let entry: ForecastEntry

    /// Days that fit under the chart without crowding it. The window's last
    /// calendar day is clipped by where the forecast ends, so its numbers
    /// don't belong in a column of whole-day ones.
    private var listedDays: [ForecastDay] {
        var days = entry.days
        if days.count > 1, days.last?.isPartial == true { days.removeLast() }
        return Array(days.prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForecastHeader(entry: entry, size: 11)

            if entry.slots.isEmpty {
                ForecastUnavailable(message: entry.errorMessage)
            } else {
                ForecastSkyline(entry: entry, showYAxis: true)
                    .frame(minHeight: 120, maxHeight: .infinity)

                Divider()

                VStack(spacing: 0) {
                    // Without these the middle number reads as just another
                    // price between two timestamped ones.
                    HStack(spacing: 0) {
                        Spacer()
                        Text("Cheapest").frame(width: 74, alignment: .trailing)
                        Text("Avg").frame(width: 44, alignment: .trailing)
                        Text("Peak").frame(width: 74, alignment: .trailing)
                    }
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 1)

                    ForEach(listedDays) { day in
                        HStack(spacing: 0) {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(day.isConfirmed ? Color.secondary : Color.secondary.opacity(0.3))
                                    .frame(width: 4, height: 4)
                                Text(shortDayLabel(day.start))
                                    .font(.system(.caption2, design: .rounded))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            priceCell(day.cheapest)
                            Text(String(format: "%.1fp", day.average))
                                .font(.system(.caption2, design: .monospaced))
                                .frame(width: 44, alignment: .trailing)
                            priceCell(day.peak)
                        }
                        .padding(.vertical, 1.5)
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func priceCell(_ slot: ForecastSlot?) -> some View {
        if let slot {
            HStack(spacing: 3) {
                Text(slotTimeFormatter.string(from: slot.validFrom))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Text(String(format: "%.1fp", slot.price))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(PriceCategory.from(slot.price).color)
            }
            .frame(width: 74, alignment: .trailing)
        } else {
            Text("—")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .trailing)
        }
    }
}

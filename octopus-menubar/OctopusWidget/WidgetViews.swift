import SwiftUI
import Charts
import WidgetKit

// MARK: - Entry View (dispatches by size)

struct OctopusWidgetEntryView: View {
    let entry: PriceEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            LargeWidgetView(entry: entry)
        }
    }
}

// MARK: - Small

struct SmallWidgetView: View {
    let entry: PriceEntry

    private var currentSlot: PriceSlot? {
        guard entry.currentIndex < entry.slots.count else { return nil }
        return entry.slots[entry.currentIndex]
    }

    private var upcomingSlots: [PriceSlot] {
        let start = min(entry.currentIndex + 1, entry.slots.count)
        return Array(entry.slots[start...].prefix(6))
    }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.region.displayName.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces) ?? entry.region.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let slot = currentSlot {
                Text(String(format: "%.2fp", slot.valueIncVat))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                Text(timeFormatter.string(from: slot.validFrom))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("—")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No data")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini sparkline of next 6 slots
            if !upcomingSlots.isEmpty {
                Chart {
                    ForEach(Array(upcomingSlots.enumerated()), id: \.offset) { i, slot in
                        BarMark(
                            x: .value("Slot", i),
                            y: .value("p", slot.valueIncVat)
                        )
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color.opacity(0.7))
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 30)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Medium

struct MediumWidgetView: View {
    let entry: PriceEntry

    private var currentSlot: PriceSlot? {
        guard entry.currentIndex < entry.slots.count else { return nil }
        return entry.slots[entry.currentIndex]
    }

    private var axisIndices: [Int] { stride(from: 0, to: entry.slots.count, by: 8).map { $0 } }

    private let hourFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH"; f.timeZone = .current; return f
    }()

    private var yDomain: ClosedRange<Double> {
        let prices = entry.slots.map(\.valueIncVat)
        return min(prices.min() ?? 0, 0)...max(prices.max() ?? 40, 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.region.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = currentSlot {
                    Text(String(format: "Now: %.2fp", slot.valueIncVat))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                }
            }

            if entry.slots.isEmpty {
                Spacer()
                Text("Prices not yet available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Chart {
                    ForEach(Array(entry.slots.enumerated()), id: \.offset) { index, slot in
                        BarMark(
                            x: .value("Slot", index),
                            y: .value("p", slot.valueIncVat)
                        )
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color
                            .opacity(index == entry.currentIndex ? 1.0 : 0.65))
                        .cornerRadius(1)
                    }
                    if entry.currentIndex < entry.slots.count {
                        RuleMark(x: .value("Now", entry.currentIndex))
                            .foregroundStyle(.primary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisIndices) { value in
                        AxisValueLabel {
                            if let i = value.as(Int.self), i < entry.slots.count {
                                Text(hourFormatter.string(from: entry.slots[i].validFrom))
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: yDomain)
                .frame(maxHeight: .infinity)
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Large

struct LargeWidgetView: View {
    let entry: PriceEntry

    private var currentSlot: PriceSlot? {
        guard entry.currentIndex < entry.slots.count else { return nil }
        return entry.slots[entry.currentIndex]
    }

    private var upcomingSlots: [PriceSlot] {
        let start = min(entry.currentIndex + 1, entry.slots.count)
        return Array(entry.slots[start...].prefix(6))
    }

    private var axisIndices: [Int] { stride(from: 0, to: entry.slots.count, by: 8).map { $0 } }

    private let hourFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH"; f.timeZone = .current; return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
    }()

    private var yDomain: ClosedRange<Double> {
        let prices = entry.slots.map(\.valueIncVat)
        return min(prices.min() ?? 0, 0)...max(prices.max() ?? 40, 5)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.region.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = currentSlot {
                    Text(String(format: "Now: %.2fp", slot.valueIncVat))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                }
            }

            if entry.slots.isEmpty {
                Spacer()
                Text("Prices not yet available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Chart {
                    ForEach(Array(entry.slots.enumerated()), id: \.offset) { index, slot in
                        BarMark(
                            x: .value("Slot", index),
                            y: .value("p", slot.valueIncVat)
                        )
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color
                            .opacity(index == entry.currentIndex ? 1.0 : 0.65))
                        .cornerRadius(1)
                    }
                    if entry.currentIndex < entry.slots.count {
                        RuleMark(x: .value("Now", entry.currentIndex))
                            .foregroundStyle(.primary.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("now").font(.system(size: 8)).foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: axisIndices) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let i = value.as(Int.self), i < entry.slots.count {
                                Text(hourFormatter.string(from: entry.slots[i].validFrom))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis {
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
                .chartYScale(domain: yDomain)
                .frame(height: 150)

                Divider()

                // Next upcoming slots
                VStack(spacing: 0) {
                    ForEach(Array(upcomingSlots.enumerated()), id: \.offset) { _, slot in
                        HStack {
                            Text(timeFormatter.string(from: slot.validFrom))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "%.2fp", slot.valueIncVat))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(12)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

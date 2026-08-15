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

// MARK: - Formatters

private let hourFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH"; f.timeZone = .current; return f
}()

private let timeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
}()

// MARK: - Small

struct SmallWidgetView: View {
    let entry: PriceEntry

    private var upcomingSlots: [PriceSlot] { entry.upcomingSlots(limit: 6) }

    /// Position of the day change within the sparkline, when it falls inside it.
    private var dayBreak: Int? {
        guard let boundary = entry.tomorrowStartIndex else { return nil }
        let offset = boundary - entry.upcomingStart
        return upcomingSlots.indices.contains(offset) ? offset : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.region.shortName)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let slot = entry.currentSlot {
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

            // Mini sparkline of the next 6 slots, which may run into tomorrow
            if !upcomingSlots.isEmpty {
                Chart {
                    ForEach(Array(upcomingSlots.enumerated()), id: \.offset) { i, slot in
                        BarMark(
                            x: .value("Slot", i),
                            y: .value("p", slot.valueIncVat)
                        )
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color.opacity(0.7))
                    }
                    if let dayBreak {
                        RuleMark(x: .value("Tomorrow", dayBreak))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(entry.region.shortName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = entry.currentSlot {
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
                    if let boundary = entry.tomorrowStartIndex {
                        RuleMark(x: .value("Tomorrow", boundary))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: entry.axisIndices) { value in
                        AxisValueLabel {
                            if let i = value.as(Int.self), i < entry.slots.count {
                                Text(hourFormatter.string(from: entry.slots[i].validFrom))
                                    .font(.system(size: 8))
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartYScale(domain: entry.yDomain)
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

    private var upcomingSlots: [PriceSlot] { entry.upcomingSlots(limit: 6) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.region.shortName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let slot = entry.currentSlot {
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
                    if let boundary = entry.tomorrowStartIndex {
                        RuleMark(x: .value("Tomorrow", boundary))
                            .foregroundStyle(.secondary.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
                            .annotation(position: .top, alignment: .center) {
                                Text("tomorrow").font(.system(size: 8)).foregroundStyle(.secondary)
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: entry.axisIndices) { value in
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
                .chartYScale(domain: entry.yDomain)
                .frame(height: 150)

                Divider()

                // Next upcoming slots, labelled where they cross into tomorrow
                VStack(spacing: 0) {
                    ForEach(Array(upcomingSlots.enumerated()), id: \.offset) { offset, slot in
                        if entry.tomorrowStartIndex == entry.upcomingStart + offset {
                            HStack {
                                Text("Tomorrow")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.top, 2)
                        }
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

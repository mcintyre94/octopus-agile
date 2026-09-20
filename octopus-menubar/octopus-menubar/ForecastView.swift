import SwiftUI
import Charts

// MARK: - Formatters

private let slotTimeFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
}()

private let weekdayFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEE"; f.timeZone = .current; return f
}()

/// Axis labels sit a few points apart on a week-wide chart, so "Tomorrow" is
/// abbreviated where the day table can spell it out.
private func axisDayLabel(_ start: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(start) { return "Today" }
    if calendar.isDateInTomorrow(start) { return "Tmrw" }
    return weekdayFormatter.string(from: start)
}

private let dayFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEE d"; f.timeZone = .current; return f
}()

private let runFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = .current; return f
}()

/// "Today"/"Tomorrow" where that reads better than a date.
private func dayLabel(for start: Date, style: DateFormatter) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(start) { return "Today" }
    if calendar.isDateInTomorrow(start) { return "Tomorrow" }
    return style.string(from: start)
}

// MARK: - Forecast View

/// The 7-day tab: AgilePredict's predictions, with confirmed Octopus prices
/// swapped in for the days we already know.
struct ForecastView: View {
    let forecast: Forecast?
    let isLoading: Bool
    let error: String?

    var body: some View {
        Group {
            if isLoading && forecast == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if let error, forecast == nil {
                placeholder(
                    icon: "exclamationmark.triangle",
                    title: error,
                    detail: "Predictions come from agilepredict.com."
                )
            } else if let forecast, !forecast.slots.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForecastChartView(slots: forecast.slots)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                        legend
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        ForecastDayTable(days: forecast.days)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)

                        source(createdAt: forecast.createdAt)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                }
                .frame(maxHeight: 620)
            } else {
                placeholder(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No forecast available.",
                    detail: "Predictions come from agilepredict.com."
                )
            }
        }
    }

    private func placeholder(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(title)
                .multilineTextAlignment(.center)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary)
                    .frame(width: 12, height: 2)
                Text("price")
            }
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.25))
                    .frame(width: 14, height: 9)
                Text("predicted range")
            }
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 5, height: 5)
                Text("confirmed day")
            }
            Spacer()
        }
        .font(.system(size: 9))
        .foregroundStyle(.secondary)
    }

    private func source(createdAt: Date) -> some View {
        Text("Forecast by agilepredict.com · run at \(runFormatter.string(from: createdAt))")
            .font(.system(size: 9))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Chart

/// A week of half-hourly slots. Too many bars to label individually, so the
/// x-axis names days and rules mark the boundaries between them.
struct ForecastChartView: View {
    let slots: [ForecastSlot]

    @State private var hoveredIndex: Int? = nil

    // Derived up front rather than as computed properties: finding day
    // boundaries across a week of half-hour slots is a few hundred calendar
    // comparisons, and the body re-runs on every frame of a scrub gesture.

    /// Only the predicted slots carry a band; the confirmed run-in has none,
    /// which is the point — the ribbon starts where the certainty stops.
    private let band: [(index: Int, low: Double, high: Double)]
    private let yDomain: ClosedRange<Double>
    private let boundaries: [Int]
    private let dayStarts: [Int]
    /// Index where predictions take over from published prices, if the window
    /// starts with any published ones at all.
    private let firstPredicted: Int?

    init(slots: [ForecastSlot]) {
        self.slots = slots
        self.band = slots.enumerated().compactMap { index, slot in
            guard let low = slot.low, let high = slot.high else { return nil }
            return (index, low, high)
        }
        self.yDomain = slots.valueDomain
        self.boundaries = slots.dayBoundaryIndices
        self.dayStarts = slots.dayStartIndices
        let firstUnconfirmed = slots.firstIndex { !$0.isConfirmed }
        self.firstPredicted = (firstUnconfirmed ?? 0) > 0 ? firstUnconfirmed : nil
    }

    var body: some View {
        Chart {
            // Drawn first so the price line sits on top of the ribbon.
            ForEach(band, id: \.index) { point in
                AreaMark(
                    x: .value("Slot", point.index),
                    yStart: .value("Low", point.low),
                    yEnd: .value("High", point.high)
                )
                .foregroundStyle(Color.secondary.opacity(0.22))
            }

            // A week is 336 half-hour slots: bars would be under a point wide
            // and fill the plot with a solid slab, hiding the very band that
            // makes a forecast worth showing. The line carries the same colour
            // coding through a gradient keyed to the price axis.
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                LineMark(
                    x: .value("Slot", index),
                    y: .value("Price (p)", slot.price)
                )
            }
            .foregroundStyle(PriceCategory.gradient(over: yDomain))
            .lineStyle(StrokeStyle(lineWidth: 1.4))

            ForEach(boundaries, id: \.self) { boundary in
                RuleMark(x: .value("Day", boundary))
                    .foregroundStyle(.secondary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
            }

            // Where the published prices run out and the model takes over.
            if let firstPredicted {
                RuleMark(x: .value("Forecast", firstPredicted))
                    .foregroundStyle(.primary.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, alignment: .leading) {
                        Text("forecast")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: 180)
        .padding(.top, 10)
        .chartXScale(domain: -0.5...(Double(slots.count) - 0.5))
        .chartXAxis {
            AxisMarks(values: dayStarts) { value in
                AxisValueLabel(anchor: .topLeading) {
                    if let i = value.as(Int.self), i < slots.count {
                        Text(axisDayLabel(slots[i].validFrom))
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(v, format: .number.precision(.fractionLength(0)))p")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotOrigin = geometry[proxy.plotAreaFrame].origin
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                #if os(macOS)
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            hoveredIndex = index(at: location.x - plotOrigin.x, proxy: proxy)
                        case .ended:
                            hoveredIndex = nil
                        }
                    }
                #else
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                hoveredIndex = index(at: value.location.x - plotOrigin.x, proxy: proxy)
                            }
                            .onEnded { _ in hoveredIndex = nil }
                    )
                #endif

                if let idx = hoveredIndex, idx < slots.count {
                    tooltip(for: slots[idx])
                        .position(
                            x: tooltipX(for: idx, proxy: proxy, plotOrigin: plotOrigin, width: geometry.size.width),
                            y: 20
                        )
                }
            }
        }
    }

    private func index(at x: Double, proxy: ChartProxy) -> Int? {
        guard let idx: Int = proxy.value(atX: x), slots.indices.contains(idx) else { return nil }
        return idx
    }

    /// Keep the tooltip inside the chart rather than letting it hang off the
    /// edge — over a week the pointer spends a lot of time near the ends.
    private func tooltipX(for index: Int, proxy: ChartProxy, plotOrigin: CGPoint, width: CGFloat) -> CGFloat {
        let raw = (proxy.position(forX: index) ?? 0) + plotOrigin.x
        return min(max(raw, 60), width - 60)
    }

    @ViewBuilder
    private func tooltip(for slot: ForecastSlot) -> some View {
        VStack(spacing: 1) {
            Text(String(format: "%.2fp", slot.price))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(PriceCategory.from(slot.price).color)
            Text("\(dayLabel(for: slot.validFrom, style: dayFormatter)) \(slotTimeFormatter.string(from: slot.validFrom))")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            if let low = slot.low, let high = slot.high {
                Text(String(format: "%.1f – %.1fp", low, high))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
        .shadow(radius: 2)
        .fixedSize()
    }
}

// MARK: - Per-day summary

/// A week of half-hourly slots is too many rows to list, so each day is
/// summarised by the numbers you'd actually plan around.
struct ForecastDayTable: View {
    let days: [ForecastDay]

    private let columnWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                row(for: day)
                if index < days.count - 1 {
                    Divider().padding(.leading, 10)
                }
            }
        }
        .background(forecastRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(forecastRowBorder, lineWidth: 0.5)
        )
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Day")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Cheapest").frame(width: columnWidth, alignment: .trailing)
            Text("Average").frame(width: columnWidth, alignment: .trailing)
            Text("Peak").frame(width: columnWidth, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }

    private func row(for day: ForecastDay) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Circle()
                    .fill(day.isConfirmed ? Color.secondary : Color.secondary.opacity(0.3))
                    .frame(width: 5, height: 5)
                VStack(alignment: .leading, spacing: 0) {
                    Text(dayLabel(for: day.start, style: dayFormatter))
                        .font(.caption)
                    if day.isPartial {
                        Text("part day")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            extremeColumn(day.cheapest)
            averageColumn(day.average)
            extremeColumn(day.peak)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private func extremeColumn(_ slot: ForecastSlot?) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if let slot {
                Text(String(format: "%.1fp", slot.price))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(PriceCategory.from(slot.price).color)
                Text(slotTimeFormatter.string(from: slot.validFrom))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(width: columnWidth, alignment: .trailing)
    }

    private func averageColumn(_ average: Double) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(String(format: "%.1fp", average))
                .font(.system(.caption, design: .monospaced))
            Text(" ")
                .font(.system(size: 9, design: .monospaced))
        }
        .frame(width: columnWidth, alignment: .trailing)
    }
}

#if os(macOS)
import AppKit
private let forecastRowBackground = Color(nsColor: .controlBackgroundColor)
private let forecastRowBorder     = Color(nsColor: .separatorColor)
#else
import UIKit
private let forecastRowBackground = Color(uiColor: .secondarySystemGroupedBackground)
private let forecastRowBorder     = Color(uiColor: .separator)
#endif

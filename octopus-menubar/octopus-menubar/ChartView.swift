import SwiftUI
import Charts

struct ChartView: View {
    let slots: [PriceSlot]
    let currentSlotIndex: Int?

    @State private var hoveredIndex: Int? = nil

    private var yDomain: ClosedRange<Double> {
        let prices = slots.map(\.valueIncVat)
        let lo = min(prices.min() ?? 0, 0)
        let hi = max(prices.max() ?? 40, 5)
        return lo...hi
    }

    // x-axis labels every 8 slots = every 4 hours
    private var axisSlotIndices: [Int] { stride(from: 0, to: slots.count, by: 8).map { $0 } }

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = .current
        return f
    }()

    private let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH"
        f.timeZone = .current
        return f
    }()

    var body: some View {
        Chart {
            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                BarMark(
                    x: .value("Slot", index),
                    y: .value("Price (p)", slot.valueIncVat)
                )
                .foregroundStyle(
                    PriceCategory.from(slot.valueIncVat).color
                        .opacity(index == currentSlotIndex ? 1.0 : 0.65)
                )
                .cornerRadius(1)
            }

            if let idx = currentSlotIndex {
                RuleMark(x: .value("Now", idx))
                    .foregroundStyle(.primary.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("now")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(height: 160)
        .chartXAxis {
            AxisMarks(values: axisSlotIndices) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let i = value.as(Int.self), i < slots.count {
                        Text(hourFormatter.string(from: slots[i].validFrom))
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
        #if os(macOS)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                let plotOrigin = geometry[proxy.plotAreaFrame].origin
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let adjustedX = location.x - plotOrigin.x
                            if let idx: Int = proxy.value(atX: adjustedX),
                               idx >= 0, idx < slots.count {
                                hoveredIndex = idx
                            }
                        case .ended:
                            hoveredIndex = nil
                        }
                    }

                if let idx = hoveredIndex, idx < slots.count {
                    let slot = slots[idx]
                    let xPos = (proxy.position(forX: idx) ?? 0) + plotOrigin.x
                    let yPos = (proxy.position(forY: max(slot.valueIncVat, yDomain.lowerBound)) ?? 0) + plotOrigin.y

                    VStack(spacing: 1) {
                        Text(String(format: "%.2fp", slot.valueIncVat))
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                        Text(timeFormatter.string(from: slot.validFrom))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
                    .shadow(radius: 2)
                    .position(x: xPos, y: max(yPos - 28, 18))
                }
            }
        }
        #endif
    }
}

import SwiftUI

struct SlotTableView: View {
    let slots: [PriceSlot]
    let currentSlotIndex: Int?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = .current
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Price (inc. VAT)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)

            Divider()

            ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                HStack(spacing: 4) {
                    Text(timeFormatter.string(from: slot.validFrom))
                        .font(.system(.caption, design: .monospaced))
                    Text("–")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(timeFormatter.string(from: slot.validTo))
                        .font(.system(.caption, design: .monospaced))

                    if index == currentSlotIndex {
                        Text("now")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    Spacer()

                    Text(String(format: "%.2fp", slot.valueIncVat))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(PriceCategory.from(slot.valueIncVat).color)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    index == currentSlotIndex
                        ? Color.accentColor.opacity(0.1)
                        : Color.clear
                )

                if index < slots.count - 1 {
                    Divider().padding(.leading, 10)
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
    }
}

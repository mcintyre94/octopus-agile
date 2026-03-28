import WidgetKit

struct PriceEntry: TimelineEntry {
    let date: Date           // slot's validFrom — WidgetKit renders the right entry at the right time
    let slots: [PriceSlot]   // all 48 slots for the day
    let currentIndex: Int    // index of the active slot at `date`
    let region: Region
    let errorMessage: String?

    static let placeholder = PriceEntry(
        date: Date(),
        slots: [],
        currentIndex: 0,
        region: .c,
        errorMessage: nil
    )
}

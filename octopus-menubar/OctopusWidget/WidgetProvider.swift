import WidgetKit
import AppIntents

struct WidgetProvider: AppIntentTimelineProvider {
    typealias Entry = PriceEntry
    typealias Intent = RegionAppIntent

    func placeholder(in context: Context) -> PriceEntry {
        .placeholder
    }

    func snapshot(for configuration: RegionAppIntent, in context: Context) async -> PriceEntry {
        let region = Region(rawValue: configuration.regionCode) ?? .c
        let slots = (try? await OctopusService.shared.fetchSlots(region: region, date: Date())) ?? []
        return makeEntry(slots: slots, index: currentSlotIndex(in: slots), region: region, error: nil)
    }

    func timeline(for configuration: RegionAppIntent, in context: Context) async -> Timeline<PriceEntry> {
        let region = Region(rawValue: configuration.regionCode) ?? .c
        do {
            let slots = try await OctopusService.shared.fetchSlots(region: region, date: Date())
            // One entry per slot so WidgetKit advances automatically every 30 min
            let entries = slots.enumerated().map { i, slot in
                makeEntry(slots: slots, index: i, region: region, error: nil, date: slot.validFrom)
            }
            return Timeline(entries: entries, policy: .after(nextMidnight))
        } catch {
            let entry = makeEntry(slots: [], index: 0, region: region, error: error.localizedDescription)
            return Timeline(entries: [entry], policy: .after(nextMidnight))
        }
    }

    // MARK: - Helpers

    private func makeEntry(
        slots: [PriceSlot],
        index: Int,
        region: Region,
        error: String?,
        date: Date = Date()
    ) -> PriceEntry {
        PriceEntry(date: date, slots: slots, currentIndex: index, region: region, errorMessage: error)
    }

    private func currentSlotIndex(in slots: [PriceSlot]) -> Int {
        let now = Date()
        return slots.firstIndex { $0.validFrom <= now && now < $0.validTo } ?? 0
    }

    private var nextMidnight: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date())!
        return cal.startOfDay(for: tomorrow)
    }
}

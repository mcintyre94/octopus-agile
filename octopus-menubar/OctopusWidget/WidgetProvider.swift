import Foundation
import WidgetKit
import AppIntents

struct WidgetProvider: AppIntentTimelineProvider {
    typealias Entry = PriceEntry
    typealias Intent = RegionAppIntent

    /// Octopus normally publishes the next day's prices around 4pm.
    private static let publishHour = 16

    /// How often to re-check for tomorrow's prices once they're due.
    private static let retryInterval: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> PriceEntry {
        .placeholder
    }

    func snapshot(for configuration: RegionAppIntent, in context: Context) async -> PriceEntry {
        let region = configuration.region ?? .c
        let now = Date()
        guard let today = try? await OctopusService.shared.fetchSlots(region: region, date: now) else {
            return .placeholder
        }
        let tomorrow = await fetchTomorrow(region: region, from: now)
        let entries = tomorrow.isEmpty
            ? todayEntries(today, region: region)
            : rollingEntries(today: today, tomorrow: tomorrow, now: now, region: region)
        return entries.last(where: { $0.date <= now }) ?? entries.first ?? .placeholder
    }

    func timeline(for configuration: RegionAppIntent, in context: Context) async -> Timeline<PriceEntry> {
        let region = configuration.region ?? .c
        let now = Date()

        let today: [PriceSlot]
        do {
            today = try await OctopusService.shared.fetchSlots(region: region, date: now)
        } catch {
            let entry = makeEntry(date: now, slots: [], region: region, error: error.localizedDescription)
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.retryInterval)))
        }

        // Tomorrow is best-effort: an empty response (or a failed request) just
        // means "not published yet", and we stay on today's window.
        let tomorrow = await fetchTomorrow(region: region, from: now)

        let entries = tomorrow.isEmpty
            ? todayEntries(today, region: region)
            : rollingEntries(today: today, tomorrow: tomorrow, now: now, region: region)

        // Once tomorrow is in hand there's nothing new until the day rolls over.
        // Until then, keep checking so the widget picks the prices up promptly.
        let reload = tomorrow.isEmpty ? nextTomorrowCheck(from: now) : nextMidnight(after: now)

        guard !entries.isEmpty else {
            let entry = makeEntry(date: now, slots: [], region: region, error: nil)
            return Timeline(entries: [entry], policy: .after(reload))
        }
        return Timeline(entries: entries, policy: .after(reload))
    }

    // MARK: - Fetching

    private func fetchTomorrow(region: Region, from now: Date) async -> [PriceSlot] {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else { return [] }
        return (try? await OctopusService.shared.fetchSlots(region: region, date: tomorrow)) ?? []
    }

    // MARK: - Entries

    /// Today, midnight to midnight — one entry per slot so WidgetKit advances
    /// automatically every 30 minutes.
    private func todayEntries(_ slots: [PriceSlot], region: Region) -> [PriceEntry] {
        slots.enumerated().map { index, slot in
            makeEntry(date: slot.validFrom, slots: slots, index: index, region: region, error: nil)
        }
    }

    /// Now through to the end of tomorrow. Each entry drops the slots that have
    /// already elapsed by the time it's rendered, so the graph always starts at
    /// the slot in progress.
    private func rollingEntries(
        today: [PriceSlot],
        tomorrow: [PriceSlot],
        now: Date,
        region: Region
    ) -> [PriceEntry] {
        // Guard against the two requests overlapping at the day boundary.
        let endOfToday = today.last?.validTo
        let combined = today + tomorrow.filter { slot in
            guard let endOfToday else { return true }
            return slot.validFrom >= endOfToday
        }
        guard let first = combined.firstIndex(where: { $0.validTo > now }) else { return [] }

        return (first..<combined.count).map { index in
            let window = Array(combined[index...])
            // The first entry must not be in the future, or WidgetKit has
            // nothing to render right now.
            let date = index == first ? min(now, combined[index].validFrom) : combined[index].validFrom
            return makeEntry(
                date: date,
                slots: window,
                index: 0,
                tomorrowStartIndex: dayBoundary(in: window),
                region: region,
                error: nil
            )
        }
    }

    private func makeEntry(
        date: Date,
        slots: [PriceSlot],
        index: Int = 0,
        tomorrowStartIndex: Int? = nil,
        region: Region,
        error: String?
    ) -> PriceEntry {
        PriceEntry(
            date: date,
            slots: slots,
            currentIndex: index,
            tomorrowStartIndex: tomorrowStartIndex,
            region: region,
            errorMessage: error
        )
    }

    /// Index of the first slot on the day after the window starts, if any.
    private func dayBoundary(in slots: [PriceSlot]) -> Int? {
        guard let first = slots.first else { return nil }
        let calendar = Calendar.current
        let firstDay = calendar.startOfDay(for: first.validFrom)
        return slots.firstIndex { calendar.startOfDay(for: $0.validFrom) > firstDay }
    }

    // MARK: - Reload scheduling

    private func nextMidnight(after date: Date) -> Date {
        let calendar = Calendar.current
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return date.addingTimeInterval(Self.retryInterval)
        }
        return calendar.startOfDay(for: tomorrow)
    }

    /// Wait until prices are due, then poll — but never past midnight, when
    /// today's window needs rebuilding anyway.
    private func nextTomorrowCheck(from now: Date) -> Date {
        let calendar = Calendar.current
        let publish = calendar.date(
            bySettingHour: Self.publishHour,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: now)
        )
        let next: Date
        if let publish, now < publish {
            next = publish
        } else {
            next = now.addingTimeInterval(Self.retryInterval)
        }
        return min(next, nextMidnight(after: now))
    }
}

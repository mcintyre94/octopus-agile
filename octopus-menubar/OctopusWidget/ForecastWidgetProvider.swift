import Foundation
import WidgetKit
import AppIntents

struct ForecastWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = ForecastEntry
    typealias Intent = RegionAppIntent

    /// AgilePredict publishes a new run every few hours, and the endpoint is
    /// rate-limited, so there's nothing to gain from asking more often.
    private static let reloadInterval: TimeInterval = 3 * 60 * 60

    /// Retry sooner than a full cycle when a fetch fails outright.
    private static let retryInterval: TimeInterval = 30 * 60

    /// Enough pre-rendered entries to cover the reload window if a reload runs
    /// late. Each one re-trims the window, so the chart keeps starting at the
    /// slot in progress even on stale data.
    private static let entryStride: TimeInterval = 60 * 60
    private static let entryCount = 4

    func placeholder(in context: Context) -> ForecastEntry {
        .placeholder
    }

    func snapshot(for configuration: RegionAppIntent, in context: Context) async -> ForecastEntry {
        let region = configuration.region ?? .c
        let now = Date()
        guard let forecast = try? await loadForecast(region: region) else {
            return ForecastEntry(date: now, forecast: nil, region: region)
        }
        return ForecastEntry(date: now, forecast: forecast.trimmed(to: now), region: region)
    }

    func timeline(for configuration: RegionAppIntent, in context: Context) async -> Timeline<ForecastEntry> {
        let region = configuration.region ?? .c
        let now = Date()

        let forecast: Forecast
        do {
            forecast = try await loadForecast(region: region)
        } catch {
            let entry = ForecastEntry(
                date: now,
                forecast: nil,
                region: region,
                errorMessage: error.localizedDescription
            )
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(Self.retryInterval)))
        }

        let entries = (0..<Self.entryCount).map { step -> ForecastEntry in
            let date = now.addingTimeInterval(Double(step) * Self.entryStride)
            return ForecastEntry(
                date: step == 0 ? now : date,
                forecast: forecast.trimmed(to: date),
                region: region
            )
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(Self.reloadInterval)))
    }

    /// The forecast with confirmed prices swapped in. Octopus is best-effort:
    /// if it's unreachable we still have predictions for the whole window.
    private func loadForecast(region: Region) async throws -> Forecast {
        async let predicted = AgilePredictService.shared.fetchForecast(region: region)
        async let confirmed = fetchConfirmed(region: region)
        let forecast = try await predicted
        return forecast.merging(confirmed: await confirmed)
    }

    private func fetchConfirmed(region: Region) async -> [PriceSlot] {
        let now = Date()
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) else {
            return (try? await OctopusService.shared.fetchSlots(region: region, date: now)) ?? []
        }
        async let today = OctopusService.shared.fetchSlots(region: region, date: now)
        async let next = OctopusService.shared.fetchSlots(region: region, date: tomorrow)
        return ((try? await today) ?? []) + ((try? await next) ?? [])
    }
}

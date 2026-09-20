import SwiftUI
import Combine

@MainActor
final class PriceViewModel: ObservableObject {
    // Persisted preference
    @AppStorage("selectedRegion") var selectedRegion: String = Region.c.rawValue

    // Slot data
    @Published var todaySlots:    [PriceSlot] = []
    @Published var tomorrowSlots: [PriceSlot] = []

    /// The raw AgilePredict run, before confirmed prices are folded in.
    @Published var forecast: Forecast? = nil

    // Loading / error state
    @Published var isLoadingToday:    Bool = false
    @Published var isLoadingTomorrow: Bool = false
    @Published var isLoadingForecast: Bool = false
    @Published var todayError:        String? = nil
    @Published var tomorrowError:     String? = nil
    @Published var forecastError:     String? = nil

    // UI state
    @Published var showTable: Bool = false

    private var slotTimer: AnyCancellable?

    init() {
        // Tick every 60s so currentSlotIndex stays accurate
        slotTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    var region: Region {
        Region(rawValue: selectedRegion.uppercased()) ?? .c
    }

    /// Index of the currently-active 30-min slot in todaySlots (nil if none)
    var currentSlotIndex: Int? {
        let now = Date()
        return todaySlots.firstIndex { $0.validFrom <= now && now < $0.validTo }
    }

    /// The forecast as the 7-day tab shows it: elapsed slots dropped, and
    /// confirmed Octopus prices swapped in wherever we already have them.
    ///
    /// Merging here rather than at fetch time keeps it correct however the
    /// three requests happen to interleave, and re-runs on the minute tick so
    /// the window stays current while the panel is open.
    var mergedForecast: Forecast? {
        guard let forecast else { return nil }
        return forecast
            .merging(confirmed: todaySlots + tomorrowSlots)
            .trimmed(to: Date())
    }

    func refresh() {
        Task { await fetchToday() }
        Task { await fetchTomorrow() }
        Task { await fetchForecast() }
    }

    private func fetchToday() async {
        isLoadingToday = true
        todayError = nil
        defer { isLoadingToday = false }
        do {
            todaySlots = try await OctopusService.shared.fetchSlots(region: region, date: Date())
        } catch {
            todayError = error.localizedDescription
        }
    }

    private func fetchTomorrow() async {
        isLoadingTomorrow = true
        tomorrowError = nil
        defer { isLoadingTomorrow = false }
        do {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            tomorrowSlots = try await OctopusService.shared.fetchSlots(region: region, date: tomorrow)
        } catch {
            tomorrowSlots = []
            // Only surface hard errors (not empty results, which just means "not yet")
            if case OctopusError.badStatus = error {
                tomorrowError = error.localizedDescription
            }
        }
    }

    private func fetchForecast() async {
        isLoadingForecast = true
        forecastError = nil
        defer { isLoadingForecast = false }
        do {
            forecast = try await AgilePredictService.shared.fetchForecast(region: region)
        } catch {
            forecast = nil
            forecastError = error.localizedDescription
        }
    }
}

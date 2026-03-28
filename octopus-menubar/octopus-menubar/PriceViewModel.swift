import SwiftUI
import Combine

@MainActor
final class PriceViewModel: ObservableObject {
    // Persisted preference
    @AppStorage("selectedRegion") var selectedRegion: String = Region.c.rawValue

    // Slot data
    @Published var todaySlots:    [PriceSlot] = []
    @Published var tomorrowSlots: [PriceSlot] = []

    // Loading / error state
    @Published var isLoadingToday:    Bool = false
    @Published var isLoadingTomorrow: Bool = false
    @Published var todayError:        String? = nil
    @Published var tomorrowError:     String? = nil

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

    func refresh() {
        Task { await fetchToday() }
        Task { await fetchTomorrow() }
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
}

import SwiftUI

struct IOSContentView: View {
    @EnvironmentObject var viewModel: PriceViewModel
    @State private var selectedTab: Int = 0
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                DayView(
                    slots: viewModel.todaySlots,
                    isLoading: viewModel.isLoadingToday,
                    error: viewModel.todayError,
                    currentSlotIndex: viewModel.currentSlotIndex,
                    showTable: $viewModel.showTable
                )
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(0)

                DayView(
                    slots: viewModel.tomorrowSlots,
                    isLoading: viewModel.isLoadingTomorrow,
                    error: viewModel.tomorrowError,
                    currentSlotIndex: nil,
                    showTable: $viewModel.showTable
                )
                .tabItem { Label("Tomorrow", systemImage: "moon.stars") }
                .tag(1)

                ForecastView(
                    forecast: viewModel.mergedForecast,
                    isLoading: viewModel.isLoadingForecast,
                    error: viewModel.forecastError
                )
                .tabItem { Label("7 Day", systemImage: "calendar") }
                .tag(2)
            }
            .navigationTitle("Agile Prices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Region", selection: $viewModel.selectedRegion) {
                        ForEach(Region.allCases) { region in
                            Text(region.displayName).tag(region.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedRegion) { _ in
                        viewModel.refresh()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.isLoadingToday || viewModel.isLoadingTomorrow || viewModel.isLoadingForecast {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button {
                            viewModel.refresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .onAppear { viewModel.refresh() }
        // Prices go stale while the app sits in the background — tomorrow's
        // are published around 4pm, which is exactly the sort of moment you'd
        // pick the phone back up for.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.refresh() }
        }
    }
}

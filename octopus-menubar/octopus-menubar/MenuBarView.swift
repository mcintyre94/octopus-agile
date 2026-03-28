import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: PriceViewModel
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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
            }
        }
        .frame(width: 420)
        .onAppear { viewModel.refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Picker("Region", selection: $viewModel.selectedRegion) {
                ForEach(Region.allCases) { region in
                    Text(region.displayName).tag(region.rawValue)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 210)
            .onChange(of: viewModel.selectedRegion) { _ in
                viewModel.refresh()
            }

            Spacer()

            if viewModel.isLoadingToday || viewModel.isLoadingTomorrow {
                ProgressView().scaleEffect(0.6)
                    .frame(width: 20, height: 20)
            } else {
                Button {
                    viewModel.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh prices")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Day View

struct DayView: View {
    let slots: [PriceSlot]
    let isLoading: Bool
    let error: String?
    let currentSlotIndex: Int?
    @Binding var showTable: Bool

    var body: some View {
        Group {
            if isLoading && slots.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(40)
            } else if let error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if slots.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("Tomorrow's prices aren't available yet.")
                        .multilineTextAlignment(.center)
                    Text("Octopus usually publishes them around 4pm.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ChartView(slots: slots, currentSlotIndex: currentSlotIndex)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                        tableToggleButton
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                        if showTable {
                            SlotTableView(slots: slots, currentSlotIndex: currentSlotIndex)
                                .padding(.horizontal, 12)
                                .padding(.bottom, 12)
                        }
                    }
                }
                .frame(maxHeight: 620)
            }
        }
    }

    private var tableToggleButton: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showTable.toggle()
                }
            } label: {
                Label(
                    showTable ? "Hide prices" : "Show all prices",
                    systemImage: showTable ? "chevron.up" : "list.bullet"
                )
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
    }
}

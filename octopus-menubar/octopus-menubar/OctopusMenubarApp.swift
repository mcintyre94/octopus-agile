import SwiftUI

@main
struct OctopusMenubarApp: App {
    @StateObject private var viewModel = PriceViewModel()

    var body: some Scene {
        MenuBarExtra("Agile", systemImage: "bolt.fill") {
            MenuBarView()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

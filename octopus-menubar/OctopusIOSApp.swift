import SwiftUI

@main
struct OctopusIOSApp: App {
    @StateObject private var viewModel = PriceViewModel()

    var body: some Scene {
        WindowGroup {
            IOSContentView()
                .environmentObject(viewModel)
        }
    }
}

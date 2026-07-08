import SwiftUI

@main
struct PatioFinderApp: App {
    @StateObject private var viewModel = PatioViewModel()

    var body: some Scene {
        WindowGroup {
            CompassScreen(viewModel: viewModel, location: viewModel.locationService)
                .tint(Theme.accent)
        }
    }
}

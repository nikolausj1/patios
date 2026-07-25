import SwiftUI

@main
struct PatioFinderApp: App {
    @StateObject private var viewModel = PatioViewModel()
    @AppStorage("prefersDarkMode") private var prefersDarkMode = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            CompassScreen(viewModel: viewModel, location: viewModel.locationService)
                .tint(Theme.accent)
                .preferredColorScheme(prefersDarkMode ? .dark : .light)
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { viewModel.refreshIfMoved() }
                }
        }
    }
}

import Foundation
import CoreLocation
import Combine

@MainActor
final class PatioViewModel: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    // MARK: Published state
    @Published private(set) var patios: [Patio] = []      // sorted nearest-first
    @Published var selectedIndex: Int = 0
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var usingSeedData = false

    /// Owned so the whole location stack lives in one place. Views observe this too.
    let locationService = LocationService()

    // MARK: Config
    private let searchRadiusMeters: Double = 4000
    /// Re-sort the list only after the user moves at least this far.
    private let resortThresholdMeters: Double = 25

    private let seedProvider = SeedPatioProvider()
    private var liveProvider: PatioProvider?
    private var lastSortLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false
    private var hasStarted = false

    init() {
        if AppConfig.hasGooglePlacesKey {
            liveProvider = GooglePlacesProvider(apiKey: AppConfig.googlePlacesAPIKey)
        }
    }

    // MARK: Lifecycle

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        locationService.start()
        observeLocation()
    }

    private func observeLocation() {
        locationService.$location
            .compactMap { $0 }
            .sink { [weak self] loc in
                guard let self else { return }
                Task { @MainActor in self.handleLocation(loc) }
            }
            .store(in: &cancellables)
    }

    private func handleLocation(_ loc: CLLocation) {
        // First good fix → load patios.
        if !hasLoaded {
            hasLoaded = true
            lastSortLocation = loc
            Task { await load(around: loc.coordinate) }
            return
        }
        // Keep the nearest-first ordering fresh as the user moves.
        if let last = lastSortLocation, loc.distance(from: last) >= resortThresholdMeters {
            lastSortLocation = loc
            resort(around: loc)
        }
    }

    // MARK: Loading

    func refresh() {
        guard let loc = locationService.location else { return }
        Task { await load(around: loc.coordinate) }
    }

    private func load(around coordinate: CLLocationCoordinate2D) async {
        loadState = .loading
        let selectedID = currentSelectionID

        do {
            var result: [Patio]
            if let liveProvider {
                result = try await liveProvider.nearbyPatios(around: coordinate,
                                                             radiusMeters: searchRadiusMeters)
                usingSeedData = false
                // If the live call succeeds but returns nothing, fall back to seed.
                if result.isEmpty {
                    result = try await seedProvider.nearbyPatios(around: coordinate,
                                                                radiusMeters: searchRadiusMeters)
                    usingSeedData = true
                }
            } else {
                result = try await seedProvider.nearbyPatios(around: coordinate,
                                                            radiusMeters: searchRadiusMeters)
                usingSeedData = true
            }

            apply(patios: result, around: coordinate, preservingSelectionID: selectedID)
            loadState = patios.isEmpty ? .empty : .loaded
        } catch {
            // Network/decoding failure → try the offline seed so the app still works.
            if let seed = try? await seedProvider.nearbyPatios(around: coordinate,
                                                               radiusMeters: searchRadiusMeters),
               !seed.isEmpty {
                usingSeedData = true
                apply(patios: seed, around: coordinate, preservingSelectionID: selectedID)
                loadState = .loaded
            } else {
                loadState = .error(friendlyMessage(for: error))
            }
        }
    }

    private func apply(patios newPatios: [Patio],
                       around coordinate: CLLocationCoordinate2D,
                       preservingSelectionID selectedID: String?) {
        patios = sortedByDistance(newPatios, from: coordinate)
        // Keep pointing at the same patio if it's still in the list.
        if let selectedID, let idx = patios.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = idx
        } else {
            selectedIndex = 0
        }
    }

    private func resort(around location: CLLocation) {
        let selectedID = currentSelectionID
        patios = sortedByDistance(patios, from: location.coordinate)
        if let selectedID, let idx = patios.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = idx
        } else {
            selectedIndex = min(selectedIndex, max(patios.count - 1, 0))
        }
    }

    private func sortedByDistance(_ list: [Patio],
                                  from coordinate: CLLocationCoordinate2D) -> [Patio] {
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return list.sorted { origin.distance(from: $0.location) < origin.distance(from: $1.location) }
    }

    // MARK: Selection

    var selectedPatio: Patio? {
        guard patios.indices.contains(selectedIndex) else { return nil }
        return patios[selectedIndex]
    }

    private var currentSelectionID: String? { selectedPatio?.id }

    var isShowingNearest: Bool { selectedIndex == 0 }

    func selectNext() {
        guard !patios.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % patios.count
    }

    func selectPrevious() {
        guard !patios.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + patios.count) % patios.count
    }

    func select(_ patio: Patio) {
        if let idx = patios.firstIndex(of: patio) { selectedIndex = idx }
    }

    func resetToNearest() { selectedIndex = 0 }

    // MARK: Derived geometry (read live from LocationService)

    /// Straight-line distance in meters to the selected patio, if known.
    var distanceMeters: Double? {
        guard let user = locationService.location, let patio = selectedPatio else { return nil }
        return user.distance(from: patio.location)
    }

    var distanceText: String? {
        guard let meters = distanceMeters else { return nil }
        return DistanceFormatter.string(fromMeters: meters)
    }

    /// Bearing from the user to the patio, 0° = north.
    var bearingDegrees: Double? {
        guard let user = locationService.location, let patio = selectedPatio else { return nil }
        return Geo.initialBearing(from: user.coordinate, to: patio.coordinate)
    }

    /// How far to rotate the arrow given the current compass heading.
    var arrowRotationDegrees: Double? {
        guard let bearing = bearingDegrees, let heading = locationService.currentHeadingDegrees
        else { return nil }
        return Geo.arrowRotation(bearing: bearing, heading: heading)
    }

    /// True when the phone is pointed roughly at the patio.
    var isAligned: Bool {
        guard let rotation = arrowRotationDegrees else { return false }
        return abs(rotation) <= 12
    }

    var hasHeading: Bool { locationService.currentHeadingDegrees != nil }

    // MARK: Helpers

    private func friendlyMessage(for error: Error) -> String {
        if let providerError = error as? GooglePlacesProvider.ProviderError {
            switch providerError {
            case .missingAPIKey:
                return "No Google Places API key configured."
            case .badResponse(let status):
                return "Places request failed (HTTP \(status))."
            }
        }
        return "Couldn't load nearby patios."
    }
}

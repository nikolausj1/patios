import Foundation
import CoreLocation
import MapKit
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
    @Published private(set) var patios: [Patio] = []      // filtered view of allPatios, sorted nearest-first
    @Published var selectedIndex: Int = 0 {
        didSet { updateWalkingETA() }
    }
    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var usingSeedData = false
    /// e.g. "12 min walk". `nil` while unknown or unavailable.
    @Published private(set) var walkingETAText: String?
    /// Global filter: when true, `patios` excludes places known NOT to serve alcohol.
    @Published var alcoholOnly = true {
        didSet { applyFilter(preservingSelectionID: currentSelectionID) }
    }

    /// Owned so the whole location stack lives in one place. Views observe this too.
    let locationService = LocationService()

    // MARK: Config
    /// ~15 miles. Results are ranked by distance and capped at 20 by the Places
    /// API, so a wide radius self-adapts: dense city → 20 close hits; rural →
    /// the circle is wide enough to still find patios.
    private let searchRadiusMeters: Double = 24_140
    /// Re-sort the list only after the user moves at least this far.
    private let resortThresholdMeters: Double = 25
    /// Re-fetch (not just re-sort) once the user has moved this far from where
    /// we last loaded — e.g. rode across town — so stale far-away results don't linger.
    private let refetchThresholdMeters: Double = 800

    private let seedProvider = SeedPatioProvider()
    private let mapKitProvider = MapKitPatioProvider()
    private var liveProvider: PatioProvider?
    /// The full fetched+sorted set, before the alcohol-only filter is applied.
    private var allPatios: [Patio] = []
    private var lastSortLocation: CLLocation?
    private var lastLoadLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false
    private var hasStarted = false
    /// Guards against a stale MKDirections response landing after the
    /// selection has already moved on.
    private var walkingETARequestID = UUID()

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
        } else if let last = lastLoadLocation, loc.distance(from: last) >= refetchThresholdMeters {
            // Moved to a new area (e.g. rode across town) → re-fetch, not just re-sort.
            lastSortLocation = loc
            Task { await load(around: loc.coordinate) }
        } else if let last = lastSortLocation, loc.distance(from: last) >= resortThresholdMeters {
            lastSortLocation = loc
            resort(around: loc)
            updateWalkingETA()
        }
    }

    /// Call when the app returns to the foreground: re-fetches if the user has
    /// moved far enough since the last load while backgrounded.
    func refreshIfMoved() {
        guard let loc = locationService.location, let last = lastLoadLocation else { return }
        if loc.distance(from: last) >= refetchThresholdMeters {
            Task { await load(around: loc.coordinate) }
        }
    }

    // MARK: Loading

    func refresh() {
        guard let loc = locationService.location else { return }
        Task { await load(around: loc.coordinate) }
    }

    /// Google (if configured) → keyless MapKit local search → bundled seed.
    /// `usingSeedData` is only true when the seed actually supplied the data.
    private func load(around coordinate: CLLocationCoordinate2D) async {
        lastLoadLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        loadState = .loading
        let selectedID = currentSelectionID

        do {
            var result: [Patio] = []
            if let liveProvider {
                result = try await liveProvider.nearbyPatios(around: coordinate,
                                                             radiusMeters: searchRadiusMeters)
            }
            if result.isEmpty {
                result = try await mapKitProvider.nearbyPatios(around: coordinate,
                                                                radiusMeters: searchRadiusMeters)
            }
            if result.isEmpty {
                result = try await seedProvider.nearbyPatios(around: coordinate,
                                                            radiusMeters: searchRadiusMeters)
                usingSeedData = !result.isEmpty
            } else {
                usingSeedData = false
            }

            apply(patios: result, around: coordinate, preservingSelectionID: selectedID)
            loadState = patios.isEmpty ? .empty : .loaded
        } catch {
            // Any throw along the chain → try MapKit, then the offline seed.
            if let mapKitResult = try? await mapKitProvider.nearbyPatios(around: coordinate,
                                                                         radiusMeters: searchRadiusMeters),
               !mapKitResult.isEmpty {
                usingSeedData = false
                apply(patios: mapKitResult, around: coordinate, preservingSelectionID: selectedID)
                loadState = .loaded
            } else if let seed = try? await seedProvider.nearbyPatios(around: coordinate,
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
        allPatios = sortedByDistance(newPatios, from: coordinate)
        applyFilter(preservingSelectionID: selectedID)
    }

    private func resort(around location: CLLocation) {
        let selectedID = currentSelectionID
        allPatios = sortedByDistance(allPatios, from: location.coordinate)
        applyFilter(preservingSelectionID: selectedID)
    }

    /// Re-derives `patios` (the filtered, view-facing list) from `allPatios`,
    /// then restores the selection by id if possible.
    private func applyFilter(preservingSelectionID selectedID: String?) {
        var filtered = alcoholOnly ? allPatios.filter { !$0.isKnownNonAlcoholic } : allPatios
        // Safety: never empty out the app when the full set has something.
        if filtered.isEmpty && !allPatios.isEmpty { filtered = allPatios }
        patios = filtered
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

    // MARK: Walking ETA

    private func updateWalkingETA() {
        walkingETAText = nil
        guard let user = locationService.location, let patio = selectedPatio else { return }

        let requestID = UUID()
        walkingETARequestID = requestID
        let patioID = patio.id

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: user.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: patio.coordinate))
        request.transportType = .walking

        Task { [weak self] in
            guard let self else { return }
            guard let eta = try? await MKDirections(request: request).calculateETA() else { return }
            // Discard if the selection changed while the request was in flight.
            guard self.walkingETARequestID == requestID, self.selectedPatio?.id == patioID else { return }
            self.walkingETAText = Self.formatWalkingETA(seconds: eta.expectedTravelTime)
        }
    }

    private static func formatWalkingETA(seconds: TimeInterval) -> String {
        let minutes = max(1, Int((seconds / 60).rounded(.up)))
        if minutes >= 90 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours) hr walk" : "\(hours) hr \(remainder) min walk"
        }
        return "\(minutes) min walk"
    }

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

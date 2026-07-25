import Foundation
import CoreLocation

/// Wraps CoreLocation and publishes the user's location and compass heading.
@MainActor
final class LocationService: NSObject, ObservableObject {
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: CLHeading?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5              // meters
        manager.headingFilter = 1               // degrees
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    /// Screenshot hook (household Build Guide pattern): `-demoHeading <degrees>`
    /// fakes a fixed compass heading where no magnetometer exists (Simulator).
    /// Real devices launched normally never hit this path.
    private let demoHeading: Double? = {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-demoHeading"),
              args.indices.contains(idx + 1) else { return nil }
        return Double(args[idx + 1])
    }()

    /// True heading when available (needs location), otherwise magnetic heading.
    var currentHeadingDegrees: Double? {
        if let demoHeading { return demoHeading }
        guard let heading else { return nil }
        if heading.trueHeading >= 0 { return heading.trueHeading }
        return heading.magneticHeading
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.location = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in self.heading = newHeading }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    self.manager.startUpdatingHeading()
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Non-fatal: keep last known values. Errors are common indoors / on startup.
    }
}

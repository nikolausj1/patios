import Foundation
import CoreLocation
import MapKit

/// Keyless local-search fallback used when Google Places is unavailable or
/// returns nothing, and before we fall all the way back to the bundled seed.
///
/// `MKLocalSearch` needs no API key and works offline of any first-party
/// backend account, but it doesn't expose an "outdoor seating" attribute, so
/// results are a best-effort text match rather than a verified filter.
struct MapKitPatioProvider: PatioProvider {
    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant with outdoor patio seating"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [
            .restaurant, .cafe, .brewery, .winery
        ])

        let response = try await MKLocalSearch(request: request).start()
        return response.mapItems.compactMap(patio(from:))
    }

    private func patio(from item: MKMapItem) -> Patio? {
        guard let coordinate = item.placemark.location?.coordinate else { return nil }
        let name = item.name ?? "Restaurant"
        var id = "mk-\(stableHash(coordinate: coordinate, name: name))"
        // `MKMapItem.identifier` only exists on iOS 18+; deployment target is 17.
        if #available(iOS 18.0, *), let stableID = item.identifier?.rawValue {
            id = stableID
        }
        return Patio(
            id: id,
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            address: item.placemark.title,
            rating: nil,
            openNow: nil,
            servesBeer: nil,
            servesWine: nil,
            servesCocktails: nil
        )
    }

    /// `MKMapItem.identifier` isn't always present, so fall back to a stable
    /// hash of coordinate + name for a usable `Patio.id`.
    private func stableHash(coordinate: CLLocationCoordinate2D, name: String) -> Int {
        var hasher = Hasher()
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(name)
        return hasher.finalize()
    }
}

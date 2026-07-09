import Foundation
import MapKit

/// Finds nearby restaurants/patios using Apple's MapKit local search.
///
/// Requires **no API key or billing** — it uses the same search that powers
/// Apple Maps. Apple doesn't expose a strict "has outdoor seating" flag, so this
/// returns nearby dining spots biased toward patios via the search query; for a
/// verified outdoor-seating filter, configure a Google Places key instead.
struct MapKitPatioProvider: PatioProvider {
    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "outdoor patio restaurant"
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: radiusMeters * 2,
            longitudinalMeters: radiusMeters * 2
        )

        let response = try await MKLocalSearch(request: request).start()

        return response.mapItems.compactMap { item -> Patio? in
            guard let location = item.placemark.location else { return nil }
            let coord = location.coordinate
            return Patio(
                id: "mk-\(coord.latitude),\(coord.longitude)-\(item.name ?? "")",
                name: item.name ?? "Restaurant",
                latitude: coord.latitude,
                longitude: coord.longitude,
                address: item.placemark.title,
                rating: nil
            )
        }
    }
}

import Foundation
import CoreLocation

/// Anything that can supply nearby patios for a location.
protocol PatioProvider {
    /// Fetches patios near `coordinate` within `radius` meters, closest handling
    /// left to the caller. Throws on network/decoding errors.
    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio]
}

/// Loads the bundled `Patios.json` seed list. Used as a demo/offline fallback
/// when no Google Places API key is configured or the network call fails.
struct SeedPatioProvider: PatioProvider {
    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        guard let url = Bundle.main.url(forResource: "Patios", withExtension: "json") else {
            return []
        }
        let data = try Data(contentsOf: url)
        let list = try JSONDecoder().decode(Patio.SeedList.self, from: data)
        return list.patios.map(\.patio)
    }
}

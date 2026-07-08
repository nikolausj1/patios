import Foundation
import CoreLocation

/// Fetches nearby restaurants with outdoor seating from the Google Places API (New).
///
/// Uses the `places:searchNearby` endpoint with a field mask that includes
/// `outdoorSeating`, then keeps places where that attribute is `true`.
/// See: https://developers.google.com/maps/documentation/places/web-service/nearby-search
struct GooglePlacesProvider: PatioProvider {
    enum ProviderError: Error {
        case missingAPIKey
        case badResponse(status: Int)
    }

    let apiKey: String

    private let endpoint = URL(string: "https://places.googleapis.com/v1/places:searchNearby")!

    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        guard !apiKey.isEmpty else { throw ProviderError.missingAPIKey }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.id,places.displayName,places.location,places.formattedAddress,places.rating,places.outdoorSeating",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )

        let body = RequestBody(
            includedTypes: ["restaurant"],
            maxResultCount: 20,
            rankPreference: "DISTANCE",
            locationRestriction: .init(
                circle: .init(
                    center: .init(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude),
                    radius: radiusMeters
                )
            )
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse(status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.badResponse(status: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
        let all = decoded.places ?? []

        // Prefer places explicitly flagged with outdoor seating. If the attribute
        // is unknown for every result, fall back to all restaurants so the arrow
        // still has something to point at.
        let withPatio = all.filter { $0.hasOutdoorSeating }
        let chosen = withPatio.isEmpty ? all : withPatio
        return chosen.compactMap { $0.patio }
    }
}

// MARK: - Request / Response DTOs

private extension GooglePlacesProvider {
    struct RequestBody: Encodable {
        let includedTypes: [String]
        let maxResultCount: Int
        let rankPreference: String
        let locationRestriction: LocationRestriction

        struct LocationRestriction: Encodable {
            let circle: Circle
        }
        struct Circle: Encodable {
            let center: Center
            let radius: Double
        }
        struct Center: Encodable {
            let latitude: Double
            let longitude: Double
        }
    }

    struct SearchResponse: Decodable {
        let places: [Place]?
    }

    struct Place: Decodable {
        let id: String
        let displayName: DisplayName?
        let location: Location?
        let formattedAddress: String?
        let rating: Double?
        let outdoorSeating: Bool?

        struct DisplayName: Decodable { let text: String }
        struct Location: Decodable { let latitude: Double; let longitude: Double }

        var hasOutdoorSeating: Bool { outdoorSeating == true }

        var patio: Patio? {
            guard let location else { return nil }
            return Patio(
                id: id,
                name: displayName?.text ?? "Restaurant",
                latitude: location.latitude,
                longitude: location.longitude,
                address: formattedAddress,
                rating: rating
            )
        }
    }
}

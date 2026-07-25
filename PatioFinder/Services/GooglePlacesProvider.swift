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

    /// searchNearby caps results at 20, so the ranking + radius decide what those
    /// 20 slots hold. Popularity within a compact radius gives a dense city its
    /// prominent nearby patios; distance over the full radius is the wider net a
    /// sparse/rural area needs. We do the compact-popularity pass first and only
    /// widen when it comes back thin — self-adapting city vs country.
    private let compactRadiusMeters: Double = 4000    // ~2.5 mi
    private let thinResultThreshold = 5

    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        guard !apiKey.isEmpty else { throw ProviderError.missingAPIKey }

        let compact = min(compactRadiusMeters, radiusMeters)
        var places = try await fetch(around: coordinate, radius: compact, rank: "POPULARITY")
        var withPatio = places.filter { $0.hasOutdoorSeating }

        // Sparse area: widen with a distance-ranked pass over the full radius and
        // merge in anything new, so rural users still get the far-flung patios.
        if withPatio.count < thinResultThreshold, compact < radiusMeters {
            let seen = Set(places.map(\.id))
            let wider = try await fetch(around: coordinate, radius: radiusMeters, rank: "DISTANCE")
            places += wider.filter { !seen.contains($0.id) }
            withPatio = places.filter { $0.hasOutdoorSeating }
        }

        // Prefer places explicitly flagged with outdoor seating. If the attribute
        // is unknown for every result, fall back to all so the arrow still has
        // something to point at.
        let chosen = withPatio.isEmpty ? places : withPatio
        return chosen.compactMap { $0.patio }
    }

    /// One `places:searchNearby` call. Broadened beyond restaurants (bars, cafés,
    /// and bakeries have patios too).
    private func fetch(around coordinate: CLLocationCoordinate2D,
                       radius: Double,
                       rank: String) async throws -> [Place] {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(
            "places.id,places.displayName,places.location,places.formattedAddress,places.rating,places.outdoorSeating,places.currentOpeningHours.openNow,places.servesBeer,places.servesWine,places.servesCocktails",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        // Required for iOS-restricted API keys: the Maps SDK sends this
        // automatically, but our raw URLSession requests must set it or Google
        // returns 403 (API_KEY_IOS_APP_BLOCKED) and we silently fall back to MapKit.
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }

        let body = RequestBody(
            includedTypes: ["restaurant", "bar", "cafe", "bakery"],
            maxResultCount: 20,
            rankPreference: rank,
            locationRestriction: .init(
                circle: .init(
                    center: .init(latitude: coordinate.latitude,
                                  longitude: coordinate.longitude),
                    radius: radius
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
        return try JSONDecoder().decode(SearchResponse.self, from: data).places ?? []
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
        let currentOpeningHours: CurrentOpeningHours?
        let servesBeer: Bool?
        let servesWine: Bool?
        let servesCocktails: Bool?

        struct DisplayName: Decodable { let text: String }
        struct Location: Decodable { let latitude: Double; let longitude: Double }
        struct CurrentOpeningHours: Decodable { let openNow: Bool? }

        var hasOutdoorSeating: Bool { outdoorSeating == true }

        var patio: Patio? {
            guard let location else { return nil }
            return Patio(
                id: id,
                name: displayName?.text ?? "Restaurant",
                latitude: location.latitude,
                longitude: location.longitude,
                address: formattedAddress,
                rating: rating,
                openNow: currentOpeningHours?.openNow,
                servesBeer: servesBeer,
                servesWine: servesWine,
                servesCocktails: servesCocktails
            )
        }
    }
}

import Foundation
import CoreLocation

/// Fetches nearby restaurants and bars with outdoor seating from the Google
/// Places API (New).
///
/// Primary strategy is `places:searchText` for "restaurant or bar with
/// outdoor patio seating," paged up to 3 times. `searchNearby` caps out at 20
/// results and its ranking options (popularity / distance) have no notion of
/// "has a patio," so in a dense area those 20 slots often fill up with
/// patio-less places before any real patios show up. Text search pages to 60
/// results and ranks by relevance to the patio-flavored query itself, which
/// starves less and finds far more genuine patios.
///
/// A small distance-ranked `searchNearby` pass over the immediate ~500m acts
/// as a safety net for the closest block, since text search's relevance
/// ranking could in principle skip something right around the corner; only
/// its outdoor-seating-confirmed results are merged in.
///
/// If the combined confirmed-patio count is still thin (rural / sparse
/// area), one further text-search page is issued with a much wider location
/// bias.
///
/// See:
/// https://developers.google.com/maps/documentation/places/web-service/text-search
/// https://developers.google.com/maps/documentation/places/web-service/nearby-search
struct GooglePlacesProvider: PatioProvider {
    enum ProviderError: Error {
        case missingAPIKey
        case badResponse(status: Int)
    }

    let apiKey: String

    private let textSearchEndpoint = URL(string: "https://places.googleapis.com/v1/places:searchText")!
    private let nearbyEndpoint = URL(string: "https://places.googleapis.com/v1/places:searchNearby")!

    private let fieldMaskBase =
        "places.id,places.displayName,places.location,places.formattedAddress,places.rating,places.currentOpeningHours.openNow,places.outdoorSeating,places.servesBeer,places.servesWine,places.servesCocktails"
    // nextPageToken is only meaningful (and only returned) by searchText.
    private var fieldMaskWithPaging: String { fieldMaskBase + ",nextPageToken" }

    private let textSearchBiasRadiusMeters: Double = 2000
    private let nearbySafetyNetRadiusMeters: Double = 500
    private let maxTextSearchPages = 3
    private let thinResultThreshold = 5
    private let ruralWideningCapMeters: Double = 50_000

    func nearbyPatios(around coordinate: CLLocationCoordinate2D,
                      radiusMeters: Double) async throws -> [Patio] {
        guard !apiKey.isEmpty else { throw ProviderError.missingAPIKey }

        // 1. Primary: paged text search biased to the immediate area. This is
        // what fixes recall versus the old searchNearby-only approach.
        var places = try await pagedTextSearch(around: coordinate, biasRadius: textSearchBiasRadiusMeters)
        var seen = Set(places.map(\.id))

        // 2. Safety net: one distance-ranked nearby pass over the closest
        // block. Only keep results explicitly flagged with outdoor seating,
        // since nearby search's own ranking isn't patio-aware; text-search
        // results already in `places` win any id collision.
        let nearby = try await searchNearby(around: coordinate, radius: nearbySafetyNetRadiusMeters)
        for place in nearby where place.hasOutdoorSeating && !seen.contains(place.id) {
            places.append(place)
            seen.insert(place.id)
        }

        // 3. Rural widening: if the confirmed-patio count from 1+2 is still
        // thin, issue one more text-search page with a much wider location
        // bias. `radiusMeters` (the caller's search radius, ~15mi/24km by
        // default) is used only here, to cap how wide that pass goes.
        if places.filter(\.hasOutdoorSeating).count < thinResultThreshold {
            let widerRadius = min(radiusMeters, ruralWideningCapMeters)
            let (widerPlaces, _) = try await searchText(around: coordinate, radius: widerRadius, pageToken: nil)
            for place in widerPlaces where !seen.contains(place.id) {
                places.append(place)
                seen.insert(place.id)
            }
        }

        // Prefer places whose outdoor seating isn't explicitly false. Unknowns
        // that matched the patio-focused text query are very likely patios
        // too (live testing shows ~98% of them report outdoorSeating == true
        // anyway). If somehow nothing survives that filter, fall back to all
        // results so the arrow still has something to point at.
        let withPatio = places.filter { $0.outdoorSeating != false }
        let chosen = withPatio.isEmpty ? places : withPatio
        return chosen.compactMap { $0.patio }
    }

    /// Runs `searchText` pages starting from page 1, accumulating results,
    /// until `maxTextSearchPages` is reached or a page comes back without a
    /// `nextPageToken`.
    private func pagedTextSearch(around coordinate: CLLocationCoordinate2D,
                                  biasRadius: Double) async throws -> [Place] {
        var places: [Place] = []
        var pageToken: String?

        for _ in 0..<maxTextSearchPages {
            let (page, nextToken) = try await searchText(around: coordinate, radius: biasRadius, pageToken: pageToken)
            places += page
            guard let nextToken else { break }
            pageToken = nextToken
        }
        return places
    }

    /// One `places:searchText` call for "restaurant or bar with outdoor patio
    /// seating," biased toward `coordinate`. Returns the page's places plus
    /// the token for the next page, if any.
    private func searchText(around coordinate: CLLocationCoordinate2D,
                            radius: Double,
                            pageToken: String?) async throws -> (places: [Place], nextPageToken: String?) {
        let body = TextSearchRequestBody(
            textQuery: "restaurant or bar with outdoor patio seating",
            pageSize: 20,
            locationBias: .init(
                circle: .init(
                    center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    radius: radius
                )
            ),
            pageToken: pageToken
        )
        let response = try await execute(url: textSearchEndpoint, body: body, fieldMask: fieldMaskWithPaging)
        return (response.places ?? [], response.nextPageToken)
    }

    /// One distance-ranked `places:searchNearby` call over `radius` meters.
    /// Broadened beyond restaurants (bars, cafés, and bakeries have patios
    /// too).
    private func searchNearby(around coordinate: CLLocationCoordinate2D,
                              radius: Double) async throws -> [Place] {
        let body = NearbyRequestBody(
            includedTypes: ["restaurant", "bar", "cafe", "bakery"],
            maxResultCount: 20,
            rankPreference: "DISTANCE",
            locationRestriction: .init(
                circle: .init(
                    center: .init(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    radius: radius
                )
            )
        )
        let response = try await execute(url: nearbyEndpoint, body: body, fieldMask: fieldMaskBase)
        return response.places ?? []
    }

    /// Shared URLRequest/response boilerplate for both endpoints: JSON body,
    /// required headers, and status-code checking.
    private func execute<Body: Encodable>(url: URL, body: Body, fieldMask: String) async throws -> SearchResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.setValue(fieldMask, forHTTPHeaderField: "X-Goog-FieldMask")
        // Required for iOS-restricted API keys: the Maps SDK sends this
        // automatically, but our raw URLSession requests must set it or Google
        // returns 403 (API_KEY_IOS_APP_BLOCKED) and we silently fall back to MapKit.
        if let bundleID = Bundle.main.bundleIdentifier {
            request.setValue(bundleID, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse(status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProviderError.badResponse(status: http.statusCode)
        }
        return try JSONDecoder().decode(SearchResponse.self, from: data)
    }
}

// MARK: - Request / Response DTOs

private extension GooglePlacesProvider {
    struct Circle: Encodable {
        let center: Center
        let radius: Double
    }

    struct Center: Encodable {
        let latitude: Double
        let longitude: Double
    }

    struct TextSearchRequestBody: Encodable {
        let textQuery: String
        let pageSize: Int
        let locationBias: LocationBias
        let pageToken: String?

        struct LocationBias: Encodable {
            let circle: Circle
        }

        private enum CodingKeys: String, CodingKey {
            case textQuery, pageSize, locationBias, pageToken
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(textQuery, forKey: .textQuery)
            try container.encode(pageSize, forKey: .pageSize)
            try container.encode(locationBias, forKey: .locationBias)
            // Omit entirely on page 1 rather than sending an explicit null.
            try container.encodeIfPresent(pageToken, forKey: .pageToken)
        }
    }

    struct NearbyRequestBody: Encodable {
        let includedTypes: [String]
        let maxResultCount: Int
        let rankPreference: String
        let locationRestriction: LocationRestriction

        struct LocationRestriction: Encodable {
            let circle: Circle
        }
    }

    struct SearchResponse: Decodable {
        let places: [Place]?
        let nextPageToken: String?
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

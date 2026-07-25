import Foundation
import CoreLocation

/// A restaurant with outdoor patio seating.
struct Patio: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let address: String?
    let rating: Double?
    /// Whether the place is currently open, when the source can tell us. `nil` = unknown.
    let openNow: Bool?
    /// Alcohol service flags from the source, when it can tell us. `nil` = unknown.
    let servesBeer: Bool?
    let servesWine: Bool?
    let servesCocktails: Bool?

    /// True if the source confirms this place serves any kind of alcohol.
    var servesAlcohol: Bool { servesBeer == true || servesWine == true || servesCocktails == true }
    /// True only when the source explicitly confirms NO alcohol of any kind (not merely unknown).
    var isKnownNonAlcoholic: Bool { servesBeer == false && servesWine == false && servesCocktails == false }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    /// Address trimmed for display: drops the trailing country and any zip code
    /// (Google's `formattedAddress` ends in "…, CA 94103, USA").
    var displayAddress: String? {
        guard let address else { return nil }
        var parts = address.components(separatedBy: ", ")
        if let last = parts.last, ["USA", "United States"].contains(last) {
            parts.removeLast()
        }
        let cleaned = parts
            .map { $0.replacingOccurrences(of: #"\s*\d{5}(-\d{4})?$"#,
                                           with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
    }

    static func == (lhs: Patio, rhs: Patio) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Seed / JSON decoding

/// Matches the shape of `Resources/Patios.json` used as an offline demo fallback.
extension Patio {
    struct SeedList: Decodable {
        let patios: [Seed]
    }

    struct Seed: Decodable {
        let id: String
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let rating: Double?

        var patio: Patio {
            Patio(id: id, name: name, latitude: latitude,
                  longitude: longitude, address: address, rating: rating, openNow: nil,
                  servesBeer: nil, servesWine: nil, servesCocktails: nil)
        }
    }
}

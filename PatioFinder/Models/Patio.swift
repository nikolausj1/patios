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

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
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
                  longitude: longitude, address: address, rating: rating)
        }
    }
}

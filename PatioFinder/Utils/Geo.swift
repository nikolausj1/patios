import Foundation
import CoreLocation

/// Geospatial helpers for the compass arrow.
enum Geo {
    /// Initial great-circle bearing from `from` to `to`, in degrees.
    /// 0° = true north, increasing clockwise (90° = east).
    static func initialBearing(from: CLLocationCoordinate2D,
                               to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude.radians
        let lat2 = to.latitude.radians
        let dLon = (to.longitude - from.longitude).radians

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x).degrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    /// The angle (degrees) the arrow should be rotated so it points at the target,
    /// given the device's current heading. 0° means the phone is pointed straight
    /// at the patio (arrow points up).
    static func arrowRotation(bearing: Double, heading: Double) -> Double {
        normalizeSigned(bearing - heading)
    }

    /// Normalizes an angle to the range (-180, 180].
    static func normalizeSigned(_ degrees: Double) -> Double {
        var a = degrees.truncatingRemainder(dividingBy: 360)
        if a > 180 { a -= 360 }
        if a <= -180 { a += 360 }
        return a
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

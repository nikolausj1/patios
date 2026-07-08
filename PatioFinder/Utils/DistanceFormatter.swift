import Foundation

/// Formats a distance in meters into a locale-appropriate string
/// (miles/feet in the US, kilometers/meters elsewhere).
enum DistanceFormatter {
    private static let formatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.unitOptions = .naturalScale        // picks ft/mi or m/km per locale
        f.unitStyle = .medium
        f.locale = Locale.current
        f.numberFormatter.maximumFractionDigits = 1
        return f
    }()

    /// Human-readable distance, e.g. "0.4 mi" or "320 m".
    static func string(fromMeters meters: Double) -> String {
        // Whole numbers for short distances, one decimal for longer ones.
        formatter.numberFormatter.maximumFractionDigits = meters < 1000 ? 0 : 1
        let measurement = Measurement(value: meters, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
}

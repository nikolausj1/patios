import Foundation

/// Reads build configuration surfaced through Info.plist (fed by `Config.xcconfig`).
enum AppConfig {
    /// Google Places API key, or empty string if not configured.
    static var googlePlacesAPIKey: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // A common placeholder left in the example config; treat as unset.
        if trimmed.isEmpty || trimmed == "YOUR_GOOGLE_PLACES_API_KEY" { return "" }
        return trimmed
    }

    static var hasGooglePlacesKey: Bool { !googlePlacesAPIKey.isEmpty }
}

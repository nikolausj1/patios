import Foundation
import CoreLocation
import WeatherKit

/// A one-shot "is it nice enough to sit outside" glance, backed by WeatherKit.
///
/// Fetches only the current conditions — no forecast — and reduces them to a
/// short display string plus a boolean the UI can use to call out great
/// patio weather. Failures (no entitlement, no network, throttling) are
/// swallowed; the rest of the app works fine without weather.
@MainActor
final class WeatherGlance: ObservableObject {
    @Published private(set) var summaryText: String?
    @Published private(set) var isGreatPatioWeather = false

    /// Conditions that disqualify "great patio weather" even if the
    /// temperature is in range: anything wet or severe.
    private static let disqualifyingConditions: Set<WeatherCondition> = [
        .drizzle, .freezingDrizzle, .freezingRain, .rain, .heavyRain, .sunShowers,
        .snow, .heavySnow, .flurries, .sleet, .wintryMix, .blizzard, .blowingSnow,
        .hail, .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms,
        .strongStorms, .tropicalStorm, .hurricane, .blowingDust, .smoky, .haze,
        .windy, .frigid, .hot
    ]

    private static let minGreatTempC = 15.5
    private static let maxGreatTempC = 29.5

    func refresh(for location: CLLocation) async {
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            let tempC = current.temperature.converted(to: .celsius).value
            let degree = current.temperature.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
            summaryText = "\(degree) · \(current.condition.description)"
            isGreatPatioWeather = tempC >= Self.minGreatTempC
                && tempC <= Self.maxGreatTempC
                && !Self.disqualifyingConditions.contains(current.condition)
        } catch {
            // Silent: missing entitlement, offline, or throttled — just hide the glance.
            summaryText = nil
            isGreatPatioWeather = false
        }
    }
}

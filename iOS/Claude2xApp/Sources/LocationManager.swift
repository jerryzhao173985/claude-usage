import CoreLocation
import SwiftUI

struct CityOption: Identifiable, Hashable {
    let id: String   // unique key (city name for uniqueness)
    let tzId: String // timezone identifier
    let city: String
    let country: String
    var label: String { "\(city), \(country)" }

    static let popular: [CityOption] = [
        CityOption(id: "london", tzId: "Europe/London", city: "London", country: "UK"),
        CityOption(id: "newyork", tzId: "America/New_York", city: "New York", country: "US"),
        CityOption(id: "la", tzId: "America/Los_Angeles", city: "Los Angeles", country: "US"),
        CityOption(id: "sf", tzId: "America/Los_Angeles", city: "San Francisco", country: "US"),
        CityOption(id: "sanjose", tzId: "America/Los_Angeles", city: "San Jose", country: "US"),
        CityOption(id: "paris", tzId: "Europe/Paris", city: "Paris", country: "France"),
        CityOption(id: "florence", tzId: "Europe/Rome", city: "Florence", country: "Italy"),
        CityOption(id: "amsterdam", tzId: "Europe/Amsterdam", city: "Amsterdam", country: "Netherlands"),
        CityOption(id: "reykjavik", tzId: "Atlantic/Reykjavik", city: "Reykjavik", country: "Iceland"),
        CityOption(id: "dublin", tzId: "Europe/Dublin", city: "Dublin", country: "Ireland"),
        CityOption(id: "hongkong", tzId: "Asia/Hong_Kong", city: "Hong Kong", country: "China"),
        CityOption(id: "taipei", tzId: "Asia/Taipei", city: "Taipei", country: "Taiwan"),
        CityOption(id: "beijing", tzId: "Asia/Shanghai", city: "Beijing", country: "China"),
        CityOption(id: "tokyo", tzId: "Asia/Tokyo", city: "Tokyo", country: "Japan"),
        CityOption(id: "sydney", tzId: "Australia/Sydney", city: "Sydney", country: "Australia"),
        CityOption(id: "singapore", tzId: "Asia/Singapore", city: "Singapore", country: "Singapore"),
        CityOption(id: "dubai", tzId: "Asia/Dubai", city: "Dubai", country: "UAE"),
        CityOption(id: "berlin", tzId: "Europe/Berlin", city: "Berlin", country: "Germany"),
    ]
}

@MainActor
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    @AppStorage("selectedTimezoneId") var selectedTimezoneId: String = ""
    @AppStorage("selectedCityName") var selectedCityName: String = ""
    @Published var detectedCity: String = ""

    private let clManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    var isAutoDetect: Bool { selectedTimezoneId.isEmpty }

    var activeTimezone: TimeZone {
        if selectedTimezoneId.isEmpty {
            return TimeZone.current
        }
        return TimeZone(identifier: selectedTimezoneId) ?? TimeZone.current
    }

    var displayCityName: String {
        if !selectedCityName.isEmpty { return selectedCityName }
        if !detectedCity.isEmpty { return detectedCity }
        // Fallback: extract from timezone identifier
        let name = activeTimezone.identifier
            .components(separatedBy: "/").last?
            .replacingOccurrences(of: "_", with: " ") ?? "Unknown"
        return name
    }

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyReduced // low power
    }

    func requestLocation() {
        guard isAutoDetect else { return }
        clManager.requestWhenInUseAuthorization()
        clManager.requestLocation()
    }

    func selectCity(_ city: CityOption) {
        selectedTimezoneId = city.tzId
        selectedCityName = city.label
    }

    func resetToAutoDetect() {
        selectedTimezoneId = ""
        selectedCityName = ""
        requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            Task { @MainActor [weak self] in
                if let city = placemarks?.first?.locality {
                    self?.detectedCity = city
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silent fail — timezone still works without location
    }

    // MARK: - Timezone-aware display helpers

    func peakHoursString() -> String {
        Claude2xLogic.peakHoursLocalString(in: activeTimezone)
    }

    func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeZone = activeTimezone
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}

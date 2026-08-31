import CoreLocation

/// Thin wrapper over CLLocationManager for when-in-use authorization. The map's
/// `UserAnnotation` / `MapUserLocationButton` handle the actual blue dot once
/// authorized; this just requests permission and tracks the status.
@MainActor
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    /// One-shot fix used to place the opening camera. Nil until CoreLocation
    /// answers, which is always after the map has drawn.
    private(set) var fix: CLLocationCoordinate2D?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Ask once. No-op if the user has already decided.
    func requestIfNeeded() {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// The user said no. `MapUserLocationButton` stays inert in this state, so the
    /// map has to say why — otherwise the button just looks broken.
    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorization = status
            self.requestFixIfAuthorized()
        }
    }

    /// Ask for a single fix. `UserAnnotation` draws the blue dot on its own; this
    /// exists only so the opening camera can start near the user.
    func requestFixIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: return
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in self.fix = coordinate }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // No fix is a normal outcome indoors or in the simulator. The map keeps
        // its statewide framing; nothing to surface.
    }
}

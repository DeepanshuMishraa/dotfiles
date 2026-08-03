import AppKit
import CoreLocation
import CoreWLAN

final class AppDelegate: NSObject, NSApplicationDelegate, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completed = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        locationManager.delegate = self

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else {
            resolveSSID()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            self?.finish(with: "")
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus != .notDetermined else { return }
        resolveSSID()
    }

    private func resolveSSID() {
        let status = locationManager.authorizationStatus
        guard status == .authorized || status == .authorizedAlways else {
            finish(with: "")
            return
        }

        finish(with: CWWiFiClient.shared().interface()?.ssid() ?? "")
    }

    private func finish(with value: String) {
        guard !completed else { return }
        completed = true
        print(value)
        NSApplication.shared.terminate(nil)
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()

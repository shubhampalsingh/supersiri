import Foundation
import Contacts
import MapKit
import CoreLocation
import HomeKit

// MARK: - Contacts

struct SearchContactsTool: AgentTool {
    let name = "search_contacts"
    let description = "Search the user's contacts by name and return matching names, phone numbers, and email addresses. Use this to resolve who the user means (e.g. before drafting a message to someone)."
    let statusLabel = "Looking up contacts…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "name": ["type": "string", "description": "Full or partial name to search for"],
            ],
            "required": ["name"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        guard let query = input["name"] as? String, !query.isEmpty else {
            throw AIServiceError.toolFailed(name: "Contacts", reason: "Missing name.")
        }

        let store = CNContactStore()
        let granted = (try? await store.requestAccess(for: .contacts)) ?? false
        guard granted else {
            throw AIServiceError.toolFailed(name: "Contacts", reason: "Contacts access was not granted. Enable it in iOS Settings → SuperSiri.")
        }

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
        ]
        let predicate = CNContact.predicateForContacts(matchingName: query)
        let contacts = try store.unifiedContacts(matching: predicate, keysToFetch: keys)

        guard !contacts.isEmpty else {
            return "No contacts found matching \"\(query)\"."
        }

        let lines = contacts.prefix(8).map { contact -> String in
            var line = "- \(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
            let phones = contact.phoneNumbers.map { $0.value.stringValue }
            if !phones.isEmpty { line += " | phone: \(phones.joined(separator: ", "))" }
            let emails = contact.emailAddresses.map { $0.value as String }
            if !emails.isEmpty { line += " | email: \(emails.joined(separator: ", "))" }
            return line
        }
        return "Contacts matching \"\(query)\":\n" + lines.joined(separator: "\n")
    }
}

// MARK: - Maps / Places

struct SearchPlacesTool: AgentTool {
    let name = "search_places"
    let description = "Search for real-world places (restaurants, shops, addresses, landmarks). Returns names, addresses, and Apple Maps links. Set near to a city/area, or omit it to search near the user's current location."
    let statusLabel = "Searching places…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "query": ["type": "string", "description": "What to search for, e.g. \"best ramen\" or \"pharmacy\""],
                "near": ["type": "string", "description": "Optional city or area to search around. Omit to use the user's current location."],
            ],
            "required": ["query"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        guard let query = input["query"] as? String, !query.isEmpty else {
            throw AIServiceError.toolFailed(name: "Maps", reason: "Missing query.")
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        var regionNote = ""
        if let near = input["near"] as? String, !near.isEmpty {
            let placemarks = try? await CLGeocoder().geocodeAddressString(near)
            if let location = placemarks?.first?.location {
                request.region = MKCoordinateRegion(
                    center: location.coordinate,
                    latitudinalMeters: 20_000,
                    longitudinalMeters: 20_000
                )
                regionNote = " near \(near)"
            }
        } else if let location = await OneShotLocation().current() {
            request.region = MKCoordinateRegion(
                center: location.coordinate,
                latitudinalMeters: 10_000,
                longitudinalMeters: 10_000
            )
            regionNote = " nearby"
        }

        let response = try await MKLocalSearch(request: request).start()
        guard !response.mapItems.isEmpty else {
            return "No places found for \"\(query)\"\(regionNote)."
        }

        let lines = response.mapItems.prefix(5).map { item -> String in
            let mapItemName = item.name ?? "Unknown"
            var line = "- **\(mapItemName)**"
            if let address = item.placemark.title {
                line += " — \(address)"
            }
            let encodedName = mapItemName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? mapItemName
            let coordinate = item.placemark.coordinate
            line += " ([open in Maps](https://maps.apple.com/?q=\(encodedName)&ll=\(coordinate.latitude),\(coordinate.longitude)))"
            return line
        }
        return "Places for \"\(query)\"\(regionNote):\n" + lines.joined(separator: "\n")
    }
}

/// Grabs the user's location once, with graceful failure (returns nil if
/// permission is denied or it takes too long).
final class OneShotLocation: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    func current() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.delegate = self
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters

            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                resume(with: nil)
            }

            // Don't hang the agent loop if location is slow.
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                self?.resume(with: nil)
            }
        }
    }

    private func resume(with location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            resume(with: nil)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        resume(with: locations.first)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        resume(with: nil)
    }
}

// MARK: - HomeKit

/// Shared HomeKit manager that waits for the home configuration to load.
@MainActor
final class HomeStore: NSObject, HMHomeManagerDelegate {
    static let shared = HomeStore()

    private let manager = HMHomeManager()
    private var loaded = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    func homes() async -> [HMHome] {
        if !loaded {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
                // Time out so a missing HomeKit setup doesn't hang the agent.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    self?.flushWaiters()
                }
            }
        }
        return manager.homes
    }

    nonisolated func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        Task { @MainActor in
            self.loaded = true
            self.flushWaiters()
        }
    }

    private func flushWaiters() {
        let pending = waiters
        waiters = []
        pending.forEach { $0.resume() }
    }

    /// All power-controllable services (lights, switches, outlets) across homes.
    func controllableServices() async -> [(home: String, service: HMService)] {
        var results: [(String, HMService)] = []
        for home in await homes() {
            for accessory in home.accessories {
                for service in accessory.services {
                    let controllable = service.characteristics.contains {
                        $0.characteristicType == HMCharacteristicTypePowerState
                    }
                    if controllable {
                        results.append((home.name, service))
                    }
                }
            }
        }
        return results
    }
}

struct ListHomeDevicesTool: AgentTool {
    let name = "list_home_devices"
    let description = "List the user's HomeKit devices that can be switched on or off (lights, switches, outlets), including their current state."
    let statusLabel = "Checking your home…"

    var inputSchema: [String: Any] {
        ["type": "object", "properties": [:], "required": []]
    }

    func execute(input: [String: Any]) async throws -> String {
        let services = await HomeStore.shared.controllableServices()
        guard !services.isEmpty else {
            return "No controllable HomeKit devices found. The user may not have HomeKit set up, or access may be denied."
        }
        var lines: [String] = []
        for (home, service) in services.prefix(30) {
            var state = "unknown"
            if let power = service.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypePowerState }) {
                try? await power.readValue()
                if let on = power.value as? Bool {
                    state = on ? "on" : "off"
                }
            }
            lines.append("- \(service.name) (\(home)) — \(state)")
        }
        return "Controllable home devices:\n" + lines.joined(separator: "\n")
    }
}

struct SetHomeDeviceTool: AgentTool {
    let name = "set_home_device"
    let description = "Turn a HomeKit device on or off by name. Use list_home_devices first if unsure of the exact name."
    let statusLabel = "Controlling your home…"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "device": ["type": "string", "description": "Device (service) name, e.g. \"Living Room Lamp\""],
                "on": ["type": "boolean", "description": "true to turn on, false to turn off"],
            ],
            "required": ["device", "on"],
        ]
    }

    func execute(input: [String: Any]) async throws -> String {
        guard let deviceName = input["device"] as? String,
              let on = input["on"] as? Bool
        else {
            throw AIServiceError.toolFailed(name: "Home", reason: "Missing device or on/off state.")
        }

        let services = await HomeStore.shared.controllableServices()
        guard let match = services.first(where: {
            $0.service.name.localizedCaseInsensitiveContains(deviceName)
        }) else {
            let available = services.map { "\"\($0.service.name)\"" }.joined(separator: ", ")
            throw AIServiceError.toolFailed(
                name: "Home",
                reason: "No device matching \"\(deviceName)\". Available: \(available.isEmpty ? "none" : available)."
            )
        }

        guard let power = match.service.characteristics.first(where: {
            $0.characteristicType == HMCharacteristicTypePowerState
        }) else {
            throw AIServiceError.toolFailed(name: "Home", reason: "\(match.service.name) can't be switched on/off.")
        }

        try await power.writeValue(on)
        return "Turned \(match.service.name) \(on ? "on" : "off")."
    }
}

//
//  HomeKitManager.swift
//  OS One
//
//  Created by Simon Loffler on 13/5/2025.
//

import SwiftUI
import HomeKit

class HomeKitManager: NSObject, ObservableObject, HMHomeManagerDelegate {
    // MARK: – Published state for UI binding
    @Published var homes: [HMHome] = []
    @Published var rooms: [HMRoom] = []
    @Published var accessories: [HMAccessory] = []
    @Published var characteristics: [HMCharacteristic] = []
    @Published var llmOutput: String = ""
    @Published var errorMessage: String? = nil

    // MARK: – Private helpers
    private var homeManager: HMHomeManager!
    private var isInitialized = false
    private var isAuthorizing = false

    // MARK: – Init / authorisation
    override init() {
        super.init()
        homeManager = HMHomeManager()
        homeManager.delegate = self
        checkAuthorizationStatus()
    }

    private func checkAuthorizationStatus() {
        if #available(iOS 18.0, *) {
            switch homeManager.authorizationStatus {
            case .authorized:
                isAuthorizing = false
                print("HomeKit authorised")
            case .restricted:
                isAuthorizing = false
                errorMessage = "HomeKit access denied or restricted. Enable in Settings > Privacy > HomeKit."
                print("HomeKit access denied or restricted")
            default:
                print("Unknown HomeKit authorisation status")
            }
        } else {
            // Prior to iOS 18 HomeKit does not expose an authorisation API, so we assume undetermined
            isAuthorizing = true
            print("HomeKit authorisation status unavailable (< iOS 18), assuming undetermined")
        }
    }

    // MARK: – HMHomeManagerDelegate
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        checkAuthorizationStatus()

        guard !manager.homes.isEmpty else {
            errorMessage = "No HomeKit homes found. Set up a home in the Home app first."
            print("No HomeKit homes found")
            return
        }

        errorMessage = nil
        homes = manager.homes
        rooms = manager.homes.flatMap { $0.rooms }

        // Trigger a scan so the new home/room lists are reflected in the summary
        scanAccessories { _ in
            self.isInitialized = true
            self.isAuthorizing = false
            print("HomeKit initialisation complete – homes: \(self.homes.count), rooms: \(self.rooms.count)")
        }
    }

    // MARK: – Accessory / characteristic discovery
    func scanAccessories(completion: @escaping (Bool) -> Void) {
        accessories.removeAll()
        characteristics.removeAll()

        for home in homes {
            for accessory in home.accessories {
                accessories.append(accessory)
                scanCharacteristics(for: accessory)
            }
        }

        generateLLMOutput()
        completion(true)
    }

    private func scanCharacteristics(for accessory: HMAccessory) {
        for service in accessory.services {
            for characteristic in service.characteristics {
                characteristics.append(characteristic)

                // Only read values for readable characteristics; write‑only values are skipped
                if characteristic.properties.contains(HMCharacteristicPropertyReadable) {
                    characteristic.readValue { error in
                        if let error {
                            print("Error reading characteristic: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.errorMessage = "Failed to read characteristic value (\(error.localizedDescription))."
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: – LLM summary generation
    private func generateLLMOutput() {
        var lines: [String] = []

        lines.append("Below is a snapshot of every detected HomeKit room including its devices and current readings. Use this to answer questions about the household setup.\n")

        for home in homes {
            lines.append("Home: \(home.name)")

            for room in home.rooms {
                appendRoom(room, in: home, to: &lines)
            }

            let unassigned = home.accessories.filter { $0.room == nil }
            if !unassigned.isEmpty {
                lines.append("  Room: Unassigned")
                for accessory in unassigned {
                    appendAccessory(accessory, indent: 4, to: &lines)
                }
            }
        }

        lines.append("\nNote: Powerwall solar and load values are represented in the data as `Light Levels`, but should be reported as instantaneous power in watts (W).\n")
        llmOutput = lines.joined(separator: "\n")
    }

    private func appendRoom(_ room: HMRoom, in home: HMHome, to lines: inout [String]) {
        lines.append("  Room: \(room.name)")

        let roomAccessories: [HMAccessory]
        if #available(iOS 16.1, *) {
            roomAccessories = room.accessories
        } else {
            roomAccessories = home.accessories.filter { $0.room?.uniqueIdentifier == room.uniqueIdentifier }
        }

        if roomAccessories.isEmpty {
            lines.append("    (No accessories detected)")
        }

        for accessory in roomAccessories {
            appendAccessory(accessory, indent: 4, to: &lines)
        }
    }

    private func appendAccessory(_ accessory: HMAccessory, indent: Int, to lines: inout [String]) {
        let pad = String(repeating: " ", count: indent)
        lines.append("\(pad)Accessory: \(accessory.name)")

        for service in accessory.services {
            for characteristic in service.characteristics where characteristic.properties.contains(HMCharacteristicPropertyReadable) {
                let label = friendlyLabel(for: characteristic, accessory: accessory, service: service)
                let valueString = characteristic.value.map { "\($0)" } ?? "Unknown"
                let unit = (label == "Solar" || label == "Load") ? " W" : ""
                lines.append("\(pad)  \(label): \(valueString)\(unit)")
            }
        }
    }

    // Best‑effort, user‑friendly name for a characteristic.
    private func friendlyLabel(for characteristic: HMCharacteristic, accessory: HMAccessory, service: HMService) -> String {
        // Map HomeKit light‑level to Solar / Load when accessory or service name hints at it
        if characteristic.characteristicType == HMCharacteristicTypeCurrentLightLevel {
            let lowerNames = (accessory.name + " " + service.name).lowercased()
            if lowerNames.contains("load") {
                return "Load"
            } else if lowerNames.contains("solar") {
                return "Solar"
            } else {
                return "Light Level"
            }
        }

        // Fallback to the system‑provided description (iOS 15+) or raw type
        if #available(iOS 15.0, *) {
            return characteristic.localizedDescription
        } else {
            return characteristic.characteristicType
        }
    }

    // MARK: – Public helper for consumers
    func fetchHomeKitData(maxRetries: Int = 3, retryDelay: TimeInterval = 1.0, completion: @escaping (String) -> Void) {
        if isAuthorizing {
            print("HomeKit is authorising; will retry after delay…")
            retryFetchHomeKitData(attempt: 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
        } else if isInitialized && !llmOutput.isEmpty {
            // Return cached snapshot and clear it so subsequent calls get fresh data
            print("Returning cached HomeKit summary (first 100 chars): \(llmOutput.prefix(100))…")
            completion(llmOutput)
            llmOutput = ""
        } else {
            // Trigger a new scan now
            scanAccessories { _ in
                DispatchQueue.main.async {
                    self.isInitialized = true
                    if self.llmOutput.isEmpty {
                        print("No data after scan; will retry…")
                        self.retryFetchHomeKitData(attempt: 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
                    } else {
                        print("HomeKit data ready (first 100 chars): \(self.llmOutput.prefix(100))…")
                        completion(self.llmOutput)
                    }
                }
            }
        }
    }

    private func retryFetchHomeKitData(attempt: Int, maxRetries: Int, retryDelay: TimeInterval, completion: @escaping (String) -> Void) {
        guard attempt <= maxRetries else {
            print("Max retries (\(maxRetries)) reached; giving up")
            completion("No HomeKit data available. Ensure a home is set up in the Home app and try again.")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            print("Retry #\(attempt)…")
            if self.isAuthorizing {
                self.retryFetchHomeKitData(attempt: attempt + 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
            } else if self.isInitialized && !self.llmOutput.isEmpty {
                print("Retry succeeded (first 100 chars): \(self.llmOutput.prefix(100))…")
                completion(self.llmOutput)
            } else {
                self.scanAccessories { _ in
                    DispatchQueue.main.async {
                        self.isInitialized = true
                        if self.llmOutput.isEmpty {
                            self.retryFetchHomeKitData(attempt: attempt + 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
                        } else {
                            completion(self.llmOutput)
                        }
                    }
                }
            }
        }
    }
}

struct HomeKitScannerView: View {
    @StateObject private var homeKitManager = HomeKitManager()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let error = homeKitManager.errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .font(.headline)
                            .padding(.bottom)
                    }

                    Group {
                        Text("Homes Found: \(homeKitManager.homes.count)")
                        Text("Rooms Found: \(homeKitManager.rooms.count)")
                        Text("Accessories Found: \(homeKitManager.accessories.count)")
                        Text("Characteristics Found: \(homeKitManager.characteristics.count)")
                    }
                    .font(.headline)

                    Divider()

                    Text("LLM‑Readable Output:")
                        .font(.title2)
                        .padding(.top)

                    Text(homeKitManager.llmOutput)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("HomeKit Scanner")
        }
        .onAppear {
            HMHomeManager().delegate = homeKitManager
        }
    }
}

struct HomeKitScannerView_Previews: PreviewProvider {
    static var previews: some View {
        HomeKitScannerView()
    }
}

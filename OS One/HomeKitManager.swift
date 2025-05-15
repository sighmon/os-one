//
//  HomeKitManager.swift
//  OS One
//
//  Created by Simon Loffler on 13/5/2025.
//

import SwiftUI
import HomeKit

class HomeKitManager: NSObject, ObservableObject, HMHomeManagerDelegate {
    @Published var homes: [HMHome] = []
    @Published var accessories: [HMAccessory] = []
    @Published var characteristics: [HMCharacteristic] = []
    @Published var llmOutput: String = ""
    @Published var errorMessage: String?
    private var homeManager: HMHomeManager!
    private var isInitialized = false
    private var isAuthorizing = false

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
                print("HomeKit authorized")
            case .restricted:
                isAuthorizing = false
                errorMessage = "HomeKit access denied or restricted. Please enable in Settings > Privacy > HomeKit."
                print("HomeKit access denied or restricted")
            default:
                print("Unknown HomeKit authorization status")
            }
        } else {
            isAuthorizing = true // Assume undetermined until homes are loaded
            print("HomeKit authorization status not available (iOS < 18.0), assuming undetermined")
        }
    }

    // MARK: - Home Manager Delegate
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        checkAuthorizationStatus()
        if manager.homes.isEmpty {
            errorMessage = "No HomeKit homes found. Please set up a home in the Home app."
            print("No HomeKit homes found")
        } else {
            errorMessage = nil
            self.homes = manager.homes
            scanAccessories { success in
                self.isInitialized = true
                self.isAuthorizing = false
                print("HomeKit initialization complete, homes: \(self.homes.count)")
            }
        }
    }

    // MARK: - Accessory Scanning
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

    // MARK: - Characteristic Scanning
    private func scanCharacteristics(for accessory: HMAccessory) {
        for service in accessory.services {
            for characteristic in service.characteristics {
                characteristics.append(characteristic)
                if characteristic.properties.contains(HMCharacteristicPropertyReadable) {
                    characteristic.readValue { error in
                        if let error = error {
                            print("Error reading characteristic: \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.errorMessage = "Failed to read characteristic: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - LLM Output Generation
    private func generateLLMOutput() {
        var output = "HomeKit Data for LLM:\n\n"

        for home in homes {
            output += "Home: \(home.name)\n"
            for accessory in home.accessories {
                output += "  Accessory: \(accessory.name) (\(accessory.uniqueIdentifier))\n"
                for service in accessory.services {
                    output += "    Service: \(service.name) (\(service.serviceType))\n"
                    for characteristic in service.characteristics {
                        let value = characteristic.value ?? "Unknown"
                        let type = characteristic.characteristicType
                        let isReadable = characteristic.properties.contains(HMCharacteristicPropertyReadable) ? "Readable" : "Not Readable"
                        output += "      Characteristic: \(type), Value: \(value), \(isReadable)\n"
                    }
                }
            }
        }

        // Append Powerwall note
        output += "\nNote: Powerwall solar/load values are the solar power produced and the home load use in Watts.\n"

        llmOutput = output
    }

    func fetchHomeKitData(maxRetries: Int = 3, retryDelay: TimeInterval = 1.0, completion: @escaping (String) -> Void) {
        if isAuthorizing {
            print("HomeKit is authorizing, retrying after delay...")
            retryFetchHomeKitData(attempt: 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
        } else if isInitialized && !llmOutput.isEmpty {
            print("Returning cached HomeKit data: \(llmOutput.prefix(100))...")
            completion(llmOutput)
        } else {
            print("HomeKit not initialized or no data, scanning...")
            scanAccessories { _ in
                DispatchQueue.main.async {
                    self.isInitialized = true
                    if self.llmOutput.isEmpty {
                        print("No HomeKit data after scan, retrying...")
                        self.retryFetchHomeKitData(attempt: 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
                    } else {
                        print("HomeKit data scanned: \(self.llmOutput.prefix(100))...")
                        completion(self.llmOutput)
                    }
                }
            }
        }
    }

    private func retryFetchHomeKitData(attempt: Int, maxRetries: Int, retryDelay: TimeInterval, completion: @escaping (String) -> Void) {
        guard attempt <= maxRetries else {
            print("Max retries (\(maxRetries)) reached, returning fallback")
            completion("No HomeKit data available. Please ensure a home is set up in the Home app and try again.")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
            print("Retry attempt \(attempt) for HomeKit data")
            if self.isAuthorizing {
                self.retryFetchHomeKitData(attempt: attempt + 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
            } else if self.isInitialized && !self.llmOutput.isEmpty {
                print("Retry successful, returning data: \(self.llmOutput.prefix(100))...")
                completion(self.llmOutput)
            } else {
                self.scanAccessories { _ in
                    DispatchQueue.main.async {
                        self.isInitialized = true
                        if self.llmOutput.isEmpty {
                            print("Retry \(attempt) failed, no data")
                            self.retryFetchHomeKitData(attempt: attempt + 1, maxRetries: maxRetries, retryDelay: retryDelay, completion: completion)
                        } else {
                            print("Retry \(attempt) successful: \(self.llmOutput.prefix(100))...")
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

                    Text("Homes Found: \(homeKitManager.homes.count)")
                        .font(.headline)

                    Text("Accessories Found: \(homeKitManager.accessories.count)")
                        .font(.headline)

                    Text("Characteristics Found: \(homeKitManager.characteristics.count)")
                        .font(.headline)

                    Divider()

                    Text("LLM Readable Output:")
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

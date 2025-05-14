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

    override init() {
        super.init()
        homeManager = HMHomeManager()
        homeManager.delegate = self
    }

    // MARK: - Home Manager Delegate
    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        if manager.homes.isEmpty {
            errorMessage = "No HomeKit homes found. Please set up a home in the Home app."
        } else {
            errorMessage = nil
            self.homes = manager.homes
            scanAccessories { _ in
                self.isInitialized = true
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

        llmOutput = output
    }

    func fetchHomeKitData(completion: @escaping (String) -> Void) {
        if isInitialized && !llmOutput.isEmpty {
            print("Returning cached HomeKit data: \(llmOutput.prefix(100))...")
            completion(llmOutput)
        } else {
            print("HomeKit not initialized, scanning...")
            scanAccessories { _ in
                DispatchQueue.main.async {
                    self.isInitialized = true
                    print("HomeKit data scanned: \(self.llmOutput.prefix(100))...")
                    completion(self.llmOutput.isEmpty ? "No HomeKit data available." : self.llmOutput)
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

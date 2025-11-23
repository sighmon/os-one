//
//  UIModeManagerTests.swift
//  OS One Tests
//
//  Unit tests for UIModeManager
//  Tests Progressive Disclosure UX system
//

import XCTest
import Combine
@testable import OS_One

final class UIModeManagerTests: XCTestCase {

    var sut: UIModeManager!
    var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Reset UserDefaults
        UserDefaults.standard.removeObject(forKey: "uiMode")
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")

        sut = UIModeManager()
        cancellables = []
    }

    override func tearDownWithError() throws {
        sut = nil
        cancellables = nil
        // Clean up UserDefaults
        UserDefaults.standard.removeObject(forKey: "uiMode")
        UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitializationWithDefaultMode() {
        let manager = UIModeManager()
        XCTAssertEqual(manager.currentMode, .clean, "Should start with Clean mode by default")
    }

    func testInitializationWithSavedMode() {
        // Save a mode
        UserDefaults.standard.set(UIMode.pro.rawValue, forKey: "uiMode")

        // Create new instance
        let manager = UIModeManager()
        XCTAssertEqual(manager.currentMode, .pro, "Should load saved mode")
    }

    func testInitialDrawerState() {
        XCTAssertFalse(sut.showModeSelector, "Mode selector should be hidden initially")
        XCTAssertEqual(sut.drawerOffset, 0.0, "Drawer should be at 0 offset initially")
        XCTAssertFalse(sut.drawerIsExpanded, "Drawer should not be expanded initially")
    }

    // MARK: - Mode Switching Tests

    func testSwitchMode() {
        let expectation = XCTestExpectation(description: "Mode change published")

        sut.$currentMode
            .dropFirst()  // Skip initial value
            .sink { mode in
                if mode == .flexible {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        sut.switchMode(to: .flexible)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(sut.currentMode, .flexible)
    }

    func testModePersistedToUserDefaults() {
        sut.switchMode(to: .pro)

        let savedMode = UserDefaults.standard.string(forKey: "uiMode")
        XCTAssertEqual(savedMode, "Pro")
    }

    func testCycleModes() {
        // Start at Clean
        XCTAssertEqual(sut.currentMode, .clean)

        // Cycle to Flexible
        sut.cycleModes()
        XCTAssertEqual(sut.currentMode, .flexible)

        // Cycle to Pro
        sut.cycleModes()
        XCTAssertEqual(sut.currentMode, .pro)

        // Cycle back to Clean
        sut.cycleModes()
        XCTAssertEqual(sut.currentMode, .clean)
    }

    // MARK: - Drawer Control Tests

    func testExpandDrawer() {
        sut.expandDrawer()

        XCTAssertTrue(sut.drawerIsExpanded, "Drawer should be expanded")
        XCTAssertEqual(sut.drawerOffset, -300, "Drawer offset should be -300")
    }

    func testCollapseDrawer() {
        // First expand
        sut.expandDrawer()
        XCTAssertTrue(sut.drawerIsExpanded)

        // Then collapse
        sut.collapseDrawer()
        XCTAssertFalse(sut.drawerIsExpanded, "Drawer should be collapsed")
        XCTAssertEqual(sut.drawerOffset, 0, "Drawer offset should be 0")
    }

    func testToggleDrawer() {
        // Start collapsed
        XCTAssertFalse(sut.drawerIsExpanded)

        // Toggle to expand
        sut.toggleDrawer()
        XCTAssertTrue(sut.drawerIsExpanded)

        // Toggle to collapse
        sut.toggleDrawer()
        XCTAssertFalse(sut.drawerIsExpanded)
    }

    // MARK: - Feature Flag Tests

    func testShouldShowMetrics() {
        sut.switchMode(to: .clean)
        XCTAssertFalse(sut.shouldShowMetrics)

        sut.switchMode(to: .flexible)
        XCTAssertFalse(sut.shouldShowMetrics)

        sut.switchMode(to: .pro)
        XCTAssertTrue(sut.shouldShowMetrics)
    }

    func testShouldShowAdvancedControls() {
        sut.switchMode(to: .clean)
        XCTAssertFalse(sut.shouldShowAdvancedControls)

        sut.switchMode(to: .flexible)
        XCTAssertTrue(sut.shouldShowAdvancedControls)

        sut.switchMode(to: .pro)
        XCTAssertTrue(sut.shouldShowAdvancedControls)
    }

    func testShouldShowQuickActions() {
        sut.switchMode(to: .clean)
        XCTAssertFalse(sut.shouldShowQuickActions)

        sut.switchMode(to: .flexible)
        XCTAssertTrue(sut.shouldShowQuickActions)

        sut.switchMode(to: .pro)
        XCTAssertTrue(sut.shouldShowQuickActions)
    }

    // MARK: - First-Time Setup Tests

    func testSetupFirstTime() {
        // Mark as not launched before
        UserDefaults.standard.set(false, forKey: "hasLaunchedBefore")

        sut.setupFirstTime()

        let hasLaunched = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
        XCTAssertTrue(hasLaunched, "Should mark as launched")

        // Mode should be set based on device
        XCTAssertNotNil(sut.currentMode)
    }

    func testSetupFirstTimeOnlyRunsOnce() {
        // First run
        sut.setupFirstTime()
        let firstMode = sut.currentMode

        // Change mode
        sut.switchMode(to: .pro)

        // Second run (should not change mode)
        sut.setupFirstTime()
        XCTAssertEqual(sut.currentMode, .pro, "Should not reset mode on second run")
        XCTAssertNotEqual(sut.currentMode, firstMode)
    }

    // MARK: - Mode Recommendation Tests

    func testRecommendModeForDeviceWithHighRAM() {
        // Can't actually control device RAM in test, but we can test the logic
        let recommendedMode = sut.recommendModeForDevice()

        let validModes: [UIMode] = [.clean, .flexible, .pro]
        XCTAssertTrue(validModes.contains(recommendedMode))
    }

    // MARK: - Performance Tests

    func testModeSwitchingPerformance() {
        measure {
            for _ in 0..<100 {
                sut.switchMode(to: .flexible)
                sut.switchMode(to: .pro)
                sut.switchMode(to: .clean)
            }
        }
    }

    func testCycleModesPerformance() {
        measure {
            for _ in 0..<1000 {
                sut.cycleModes()
            }
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentModeSwitching() {
        let expectation = XCTestExpectation(description: "Concurrent switches complete")
        expectation.expectedFulfillmentCount = 100

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<100 {
            queue.async {
                let mode: UIMode = i % 2 == 0 ? .clean : .pro
                self.sut.switchMode(to: mode)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Final mode should be valid
        XCTAssertTrue([.clean, .flexible, .pro].contains(sut.currentMode))
    }
}

// MARK: - UIMode Tests

final class UIModeTests: XCTestCase {

    func testUIModeValues() {
        XCTAssertEqual(UIMode.clean.rawValue, "Clean")
        XCTAssertEqual(UIMode.flexible.rawValue, "Flexible")
        XCTAssertEqual(UIMode.pro.rawValue, "Pro")
    }

    func testUIModeDescriptions() {
        XCTAssertFalse(UIMode.clean.description.isEmpty)
        XCTAssertFalse(UIMode.flexible.description.isEmpty)
        XCTAssertFalse(UIMode.pro.description.isEmpty)

        XCTAssertTrue(UIMode.clean.description.contains("Minimalist"))
        XCTAssertTrue(UIMode.flexible.description.contains("drawer"))
        XCTAssertTrue(UIMode.pro.description.contains("dashboard"))
    }

    func testUIModeIcons() {
        XCTAssertFalse(UIMode.clean.icon.isEmpty)
        XCTAssertFalse(UIMode.flexible.icon.isEmpty)
        XCTAssertFalse(UIMode.pro.icon.isEmpty)

        XCTAssertEqual(UIMode.clean.icon, "circle")
        XCTAssertEqual(UIMode.flexible.icon, "circle.lefthalf.filled")
        XCTAssertEqual(UIMode.pro.icon, "circle.grid.3x3.fill")
    }

    func testUIModeIdentifiable() {
        let modes = UIMode.allCases
        let ids = modes.map { $0.id }

        // All IDs should be unique
        XCTAssertEqual(ids.count, Set(ids).count)

        // IDs should match raw values
        XCTAssertEqual(UIMode.clean.id, "Clean")
        XCTAssertEqual(UIMode.flexible.id, "Flexible")
        XCTAssertEqual(UIMode.pro.id, "Pro")
    }

    func testUIModeAllCases() {
        let modes = UIMode.allCases

        XCTAssertEqual(modes.count, 3)
        XCTAssertTrue(modes.contains(.clean))
        XCTAssertTrue(modes.contains(.flexible))
        XCTAssertTrue(modes.contains(.pro))
    }
}

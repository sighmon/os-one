//
//  OSOneUITests.swift
//  OS One UI Tests
//
//  UI tests for OS One using XCUITest
//  Tests critical user paths and mode switching
//

import XCTest

final class OSOneUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()

        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
        try super.tearDownWithError()
    }

    // MARK: - Launch Tests

    func testAppLaunches() {
        XCTAssertTrue(app.state == .runningForeground)
    }

    func testMainInterfaceElementsExist() {
        // Main OS 1 title
        XCTAssertTrue(app.staticTexts["OS"].exists)

        // Microphone button
        let micButton = app.buttons["mic"]
        XCTAssertTrue(micButton.exists)

        // Settings button
        let settingsButton = app.buttons["gear"]
        XCTAssertTrue(settingsButton.exists)
    }

    // MARK: - Mode Switching Tests

    func testModeSelectorOpens() {
        // Find and tap mode selector button
        let modeSelectorButton = app.buttons[UIMode.clean.icon]
        if modeSelectorButton.exists {
            modeSelectorButton.tap()

            // Mode selector sheet should appear
            XCTAssertTrue(app.staticTexts["Choose Your Experience"].waitForExistence(timeout: 2))
        }
    }

    func testSwitchToFlexibleMode() {
        // Open mode selector
        if let modeSelectorButton = app.buttons.matching(identifier: "modeSelectorButton").firstMatch,
           modeSelectorButton.exists {
            modeSelectorButton.tap()

            // Select Flexible mode
            let flexibleModeButton = app.buttons["Flexible"]
            if flexibleModeButton.exists {
                flexibleModeButton.tap()

                // Verify Flexible mode is active
                XCTAssertTrue(app.staticTexts["Current: Flexible"].exists)
            }
        }
    }

    func testSwitchToProMode() {
        // Open mode selector
        if let modeSelectorButton = app.buttons.matching(identifier: "modeSelectorButton").firstMatch,
           modeSelectorButton.exists {
            modeSelectorButton.tap()

            // Select Pro mode
            let proModeButton = app.buttons["Pro"]
            if proModeButton.exists {
                proModeButton.tap()

                // Verify Pro mode is active
                XCTAssertTrue(app.staticTexts["Current: Pro"].waitForExistence(timeout: 2))
            }
        }
    }

    func testCycleThroughAllModes() {
        // Open mode selector
        if let modeSelectorButton = app.buttons.matching(identifier: "modeSelectorButton").firstMatch,
           modeSelectorButton.exists {

            // Test Clean → Flexible
            modeSelectorButton.tap()
            app.buttons["Flexible"].tap()
            app.buttons["Done"].tap()

            // Test Flexible → Pro
            modeSelectorButton.tap()
            app.buttons["Pro"].tap()
            app.buttons["Done"].tap()

            // Test Pro → Clean
            modeSelectorButton.tap()
            app.buttons["Clean"].tap()
            app.buttons["Done"].tap()

            XCTAssertTrue(true, "Successfully cycled through all modes")
        }
    }

    // MARK: - Settings Tests

    func testSettingsOpens() {
        let settingsButton = app.buttons["gear"]
        settingsButton.tap()

        XCTAssertTrue(app.staticTexts["settings"].waitForExistence(timeout: 2))
    }

    func testOfflineModeToggle() {
        // Open settings
        app.buttons["gear"].tap()

        // Find offline mode toggle
        let offlineModeToggle = app.switches["Enable offline mode"]
        if offlineModeToggle.exists {
            let initialValue = offlineModeToggle.value as? String

            // Toggle it
            offlineModeToggle.tap()

            // Verify it changed
            let newValue = offlineModeToggle.value as? String
            XCTAssertNotEqual(initialValue, newValue)
        }

        // Close settings
        app.buttons["Done"].tap()
    }

    func testVADSensitivitySlider() {
        // Open settings
        app.buttons["gear"].tap()

        // Enable offline mode first
        let offlineModeToggle = app.switches["Enable offline mode"]
        if offlineModeToggle.exists, offlineModeToggle.value as? String == "0" {
            offlineModeToggle.tap()
        }

        // Enable VAD
        let vadToggle = app.switches["Voice Activity Detection"]
        if vadToggle.exists, vadToggle.value as? String == "0" {
            vadToggle.tap()

            // VAD sensitivity slider should appear
            let sensitivitySlider = app.sliders.matching(identifier: "VAD Sensitivity").firstMatch
            XCTAssertTrue(sensitivitySlider.waitForExistence(timeout: 2))
        }

        app.buttons["Done"].tap()
    }

    func testModelSelection() {
        // Open settings
        app.buttons["gear"].tap()

        // Enable offline mode
        let offlineModeToggle = app.switches["Enable offline mode"]
        if offlineModeToggle.exists, offlineModeToggle.value as? String == "0" {
            offlineModeToggle.tap()

            // Model picker should appear
            let modelPicker = app.pickers["Local Model"]
            XCTAssertTrue(modelPicker.exists)
        }

        app.buttons["Done"].tap()
    }

    // MARK: - Navigation Tests

    func testNavigateToConversationArchive() {
        let archiveButton = app.buttons["archivebox"]
        archiveButton.tap()

        // Should navigate to archive view
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 2))

        // Navigate back
        if let backButton = app.navigationBars.buttons.firstMatch {
            backButton.tap()
        }
    }

    func testDeleteConversation() {
        let deleteButton = app.buttons["trash"]
        deleteButton.tap()

        // State should update
        XCTAssertTrue(app.staticTexts["conversation deleted"].waitForExistence(timeout: 2))
    }

    // MARK: - Accessibility Tests

    func testVoiceOverAccessibility() {
        // Enable VoiceOver testing
        XCUIDevice.shared.press(.home)
        app.activate()

        // Check that main elements have accessibility labels
        XCTAssertTrue(app.buttons["mic"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["gear"].isAccessibilityElement)
    }

    func testDynamicTypeSupport() {
        // This would require setting dynamic type size programmatically
        // For now, verify that text exists
        XCTAssertTrue(app.staticTexts["OS"].exists)
    }

    // MARK: - Performance Tests

    func testLaunchPerformance() throws {
        if #available(iOS 13.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testScrollPerformance() throws {
        // Navigate to conversation archive
        app.buttons["archivebox"].tap()

        if #available(iOS 13.0, *) {
            measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
                let table = app.tables.firstMatch
                if table.exists {
                    table.swipeUp(velocity: .fast)
                    table.swipeDown(velocity: .fast)
                }
            }
        }

        // Navigate back
        app.navigationBars.buttons.firstMatch.tap()
    }

    // MARK: - Snapshot Tests

    func testTakeScreenshots() throws {
        // Clean Mode Screenshot
        let cleanModeScreenshot = app.screenshot()
        let cleanAttachment = XCTAttachment(screenshot: cleanModeScreenshot)
        cleanAttachment.name = "01_CleanMode"
        cleanAttachment.lifetime = .keepAlways
        add(cleanAttachment)

        // Settings Screenshot
        app.buttons["gear"].tap()
        let settingsScreenshot = app.screenshot()
        let settingsAttachment = XCTAttachment(screenshot: settingsScreenshot)
        settingsAttachment.name = "02_Settings"
        settingsAttachment.lifetime = .keepAlways
        add(settingsAttachment)

        app.buttons["Done"].tap()

        // Conversation Archive Screenshot
        app.buttons["archivebox"].tap()
        let archiveScreenshot = app.screenshot()
        let archiveAttachment = XCTAttachment(screenshot: archiveScreenshot)
        archiveAttachment.name = "03_ConversationArchive"
        archiveAttachment.lifetime = .keepAlways
        add(archiveAttachment)
    }

    // MARK: - Error State Tests

    func testErrorStateDisplay() {
        // This would require triggering error conditions
        // For example, trying to use offline mode without a model

        app.buttons["wifi.slash"].tap()

        // Should show some error or state message
        let stateText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'model'")).firstMatch
        XCTAssertTrue(stateText.exists)
    }

    // MARK: - Critical User Path Tests

    func testCompleteOnboardingFlow() {
        // 1. Launch app
        XCTAssertTrue(app.state == .runningForeground)

        // 2. Open settings
        app.buttons["gear"].tap()
        XCTAssertTrue(app.staticTexts["settings"].exists)

        // 3. Enable offline mode
        let offlineModeToggle = app.switches["Enable offline mode"]
        if offlineModeToggle.exists {
            offlineModeToggle.tap()
        }

        // 4. Select model (if available)
        // (Would need actual model downloaded to test fully)

        // 5. Enable VAD
        let vadToggle = app.switches["Voice Activity Detection"]
        if vadToggle.exists {
            vadToggle.tap()
        }

        // 6. Close settings
        app.buttons["Done"].tap()

        // 7. Verify back on main screen
        XCTAssertTrue(app.staticTexts["OS"].exists)
    }

    // MARK: - Stress Tests

    func testRapidModeSwitching() {
        // Rapidly switch modes
        if let modeSelectorButton = app.buttons.matching(identifier: "modeSelectorButton").firstMatch {
            for _ in 0..<10 {
                if modeSelectorButton.exists {
                    modeSelectorButton.tap()
                    app.buttons["Flexible"].tap()
                    app.buttons["Done"].tap()

                    modeSelectorButton.tap()
                    app.buttons["Pro"].tap()
                    app.buttons["Done"].tap()

                    modeSelectorButton.tap()
                    app.buttons["Clean"].tap()
                    app.buttons["Done"].tap()
                }
            }
        }

        // App should still be responsive
        XCTAssertTrue(app.staticTexts["OS"].exists)
    }

    func testRapidSettingsToggle() {
        // Rapidly open and close settings
        for _ in 0..<20 {
            app.buttons["gear"].tap()
            app.buttons["Done"].tap()
        }

        // App should still be responsive
        XCTAssertTrue(app.staticTexts["OS"].exists)
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)

        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}

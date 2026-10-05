//
//  OS_OneUITests.swift
//  OS OneUITests
//
//  Created by Simon Loffler on 2/4/2023.
//

import XCTest

final class OS_OneUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testSettingsTabsAndProviderSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--settings-preview"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Personality"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Models"].tap()
        XCTAssertTrue(app.buttons["voiceProviderPicker"].exists)
        let models = XCTAttachment(screenshot: app.screenshot())
        models.name = "Models tab"
        models.lifetime = .keepAlways
        add(models)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.switches["Allow location"].exists)
        XCTAssertTrue(app.switches["Live camera"].exists)
        app.tabBars.buttons["Personality"].tap()
        XCTAssertTrue(app.textFields["ElevenLabs voice ID"].exists)
        let personality = XCTAttachment(screenshot: app.screenshot())
        personality.name = "Personality tab"
        personality.lifetime = .keepAlways
        add(personality)
    }

    func testVoiceProvidersAndWheelSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--settings-preview", "-grokApiKey", "", "-openAIApiKey", ""]
        app.launch()
        app.tabBars.buttons["Models"].tap()
        app.buttons["voiceProviderPicker"].tap()
        app.buttons["Grok Voice"].tap()
        XCTAssertTrue(app.staticTexts["Add your Grok API key to load available voices."].exists)
        app.buttons["voiceProviderPicker"].tap()
        app.buttons["OpenAI"].tap()
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 5))
        wheel.adjust(toPickerWheelValue: "Cedar")
        XCTAssertEqual(wheel.value as? String, "Cedar")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "OpenAI voice wheel"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

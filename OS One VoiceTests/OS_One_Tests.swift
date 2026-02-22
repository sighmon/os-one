//
//  OS_OneTests.swift
//  OS OneTests
//
//  Created by Simon Loffler on 2/4/2023.
//

import XCTest
@testable import OS_One

final class OS_One_Tests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testResponsesAPIEnabledForGpt5WhenSearchAllowed() throws {
        XCTAssertTrue(shouldUseResponsesAPI(grokEnabled: false, allowSearch: true, model: "gpt-5-nano-2025-08-07"))
    }

    func testResponsesAPIDisabledWhenSearchNotAllowed() throws {
        XCTAssertFalse(shouldUseResponsesAPI(grokEnabled: false, allowSearch: false, model: "gpt-5.2-2025-12-11"))
    }

    func testResponsesAPIEnabledForGrokWhenSearchAllowed() throws {
        XCTAssertTrue(shouldUseResponsesAPI(grokEnabled: true, allowSearch: true, model: "grok-4-1-fast-reasoning"))
    }

    func testWebSearchOptionsDisabledForGpt5WhenSearchAllowed() throws {
        XCTAssertFalse(shouldSendWebSearchOptions(grokEnabled: false, allowSearch: true, model: "gpt-5-nano-2025-08-07"))
    }

    func testWebSearchOptionsEnabledForNonGpt5Models() throws {
        XCTAssertTrue(shouldSendWebSearchOptions(grokEnabled: false, allowSearch: true, model: "gpt-4o-mini"))
    }

    func testGrokSearchToolNotIncludedWhenSearchAllowed() throws {
        XCTAssertFalse(shouldIncludeGrokSearchTool(grokEnabled: true, allowSearch: true))
    }

    func testGrokSearchToolNotIncludedWhenSearchDisabled() throws {
        XCTAssertFalse(shouldIncludeGrokSearchTool(grokEnabled: true, allowSearch: false))
    }

    func testXSearchToolIncludedForGrokWhenSearchAllowed() throws {
        XCTAssertTrue(shouldIncludeXSearchTool(grokEnabled: true, allowSearch: true))
    }

    func testXSearchToolNotIncludedForOpenAIWhenSearchAllowed() throws {
        XCTAssertFalse(shouldIncludeXSearchTool(grokEnabled: false, allowSearch: true))
    }

    func testBuildResponsesInputUsesInputTextForUser() throws {
        let messages: [[String: Any]] = [
            ["role": "user", "content": "Hello"]
        ]
        let input = buildResponsesInput(from: messages)
        let content = input.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["type"] as? String, "input_text")
    }

    func testBuildResponsesInputUsesOutputTextForAssistant() throws {
        let messages: [[String: Any]] = [
            ["role": "assistant", "content": "Hi"]
        ]
        let input = buildResponsesInput(from: messages)
        let content = input.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.first?["type"] as? String, "output_text")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

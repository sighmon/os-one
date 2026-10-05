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
        XCTAssertTrue(shouldUseResponsesAPI(grokEnabled: false, allowSearch: true, model: "gpt-5.4-mini"))
    }

    func testResponsesAPIDisabledWhenSearchNotAllowed() throws {
        XCTAssertFalse(shouldUseResponsesAPI(grokEnabled: false, allowSearch: false, model: "gpt-5.5"))
    }

    func testResponsesAPIEnabledForGrokWhenSearchAllowed() throws {
        XCTAssertTrue(shouldUseResponsesAPI(grokEnabled: true, allowSearch: true, model: "grok-4.3"))
    }

    func testWebSearchOptionsDisabledForGpt5WhenSearchAllowed() throws {
        XCTAssertFalse(shouldSendWebSearchOptions(grokEnabled: false, allowSearch: true, model: "gpt-5.4-mini"))
    }

    func testWebSearchOptionsDisabledForModelsWithoutSearchSupport() throws {
        XCTAssertFalse(shouldSendWebSearchOptions(grokEnabled: false, allowSearch: true, model: "gpt-4o-mini"))
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

    func testResolvedModelUsesGrokOverrideWhenGrokEnabled() throws {
        XCTAssertEqual(
            resolvedModel(
                grokEnabled: true,
                defaultOpenAIModel: "gpt-5-nano",
                overrideOpenAIModel: "gpt-4o-mini",
                grokOverrideModel: "grok-custom"
            ),
            "grok-custom"
        )
    }

    func testResolvedModelUsesOpenAIOverrideWhenGrokDisabled() throws {
        XCTAssertEqual(
            resolvedModel(
                grokEnabled: false,
                defaultOpenAIModel: "gpt-5-nano",
                overrideOpenAIModel: "gpt-4o-mini",
                grokOverrideModel: "grok-custom"
            ),
            "gpt-4o-mini"
        )
    }

    func testDefaultGrokReasoningEffortIsLowForDefaultModel() throws {
        XCTAssertEqual(defaultGrokReasoningEffort(grokEnabled: true, grokOverrideModel: ""), "low")
    }

    func testDefaultGrokReasoningEffortIsNilForOverrideModel() throws {
        XCTAssertNil(defaultGrokReasoningEffort(grokEnabled: true, grokOverrideModel: "grok-custom"))
    }

    func testDefaultGrokReasoningEffortIsNilForOpenAI() throws {
        XCTAssertNil(defaultGrokReasoningEffort(grokEnabled: false, grokOverrideModel: ""))
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

    func testLatestOpenAIUsesResponsesWithoutEnablingSearch() {
        XCTAssertTrue(shouldUseResponsesAPI(grokEnabled: false, allowSearch: false, model: ModelCatalog.openAI[0]))
        XCTAssertFalse(shouldSendWebSearchOptions(grokEnabled: false, allowSearch: true, model: ModelCatalog.openAI[0]))
    }

    func testProviderMigrationAndExplicitSelection() {
        let suite = "OSOneTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(AssistantProvider.selected(in: defaults), .openAI)
        defaults.set(true, forKey: "grokEnabled")
        XCTAssertEqual(AssistantProvider.selected(in: defaults), .grok)
        defaults.set(true, forKey: "gatewayEnabled")
        XCTAssertEqual(AssistantProvider.selected(in: defaults), .gateway)
        defaults.set(AssistantProvider.apple.rawValue, forKey: "assistantProvider")
        XCTAssertEqual(AssistantProvider.selected(in: defaults), .apple)
    }

    func testLatestGrokAndCameraCapabilities() {
        XCTAssertEqual(resolvedModel(grokEnabled: true, defaultOpenAIModel: "unused", overrideOpenAIModel: "", grokOverrideModel: ""), ModelCatalog.grok[0])
        XCTAssertTrue(AssistantProvider.openAI.supportsCamera)
        XCTAssertTrue(AssistantProvider.grok.supportsCamera)
        XCTAssertFalse(AssistantProvider.apple.supportsCamera)
        XCTAssertFalse(AssistantProvider.gateway.supportsCamera)
    }

    func testCameraImageSurvivesResponsesConversion() {
        let input = buildResponsesInput(from: [["role": "user", "content": [
            ["type": "text", "text": "What is this?"],
            ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,frame"]]
        ]]])
        let content = input.first?["content"] as? [[String: Any]]
        XCTAssertEqual(content?.count, 2)
        XCTAssertEqual(content?.last?["type"] as? String, "input_image")
        XCTAssertEqual(content?.last?["image_url"] as? String, "data:image/jpeg;base64,frame")
    }

    private func voiceSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [VoiceStubProtocol.self]
        return URLSession(configuration: configuration)
    }

    func testGrokVoiceListUsesAuthenticatedGet() async throws {
        VoiceStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.x.ai/v1/tts/voices")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
            return (200, "application/json", Data(#"{"voices":[{"voice_id":"eve","name":"Eve"},{"voice_id":"ara","name":"Ara"},{"voice_id":"eve","name":"Eve"}]}"#.utf8))
        }
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        let voices = try await GrokSpeechAPI.voices(apiKey: " test-key ", session: session)
        XCTAssertEqual(voices.map(\.id), ["eve", "ara"])
        XCTAssertEqual(voices.map(\.name), ["Eve", "Ara"])
    }

    func testGrokMissingKeyDoesNotSendRequest() async {
        VoiceStubProtocol.handler = { _ in
            XCTFail("A missing key must not make a request")
            return (500, "application/json", Data())
        }
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        do {
            _ = try await GrokSpeechAPI.voices(apiKey: "  ", session: session)
            XCTFail("Expected missing-key error")
        } catch VoiceAPIError.missingKey {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testGrokVoiceListReportsHTTPAndEmptyListErrors() async {
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        VoiceStubProtocol.handler = { _ in (401, "application/json", Data("{}".utf8)) }
        do {
            _ = try await GrokSpeechAPI.voices(apiKey: "invalid", session: session)
            XCTFail("Expected authentication error")
        } catch VoiceAPIError.http(401) {} catch { XCTFail("Unexpected error: \(error)") }
        VoiceStubProtocol.handler = { _ in (200, "application/json", Data(#"{"voices":[]}"#.utf8)) }
        do {
            _ = try await GrokSpeechAPI.voices(apiKey: "test-key", session: session)
            XCTFail("Expected empty list error")
        } catch VoiceAPIError.noVoices {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testGrokSpeechUsesSelectedVoiceAndRejectsJSONAudio() async throws {
        let request = try GrokSpeechAPI.speechRequest(text: "Hello", voiceID: "ara", apiKey: "test-key")
        XCTAssertEqual(request.url?.absoluteString, "https://api.x.ai/v1/tts")
        XCTAssertEqual(request.httpMethod, "POST")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(body["voice_id"] as? String, "ara")
        XCTAssertEqual(body["language"] as? String, "auto")
        XCTAssertEqual(body["text"] as? String, "Hello")
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        VoiceStubProtocol.handler = { _ in (200, "audio/mpeg", Data([1, 2, 3])) }
        let audio = try await GrokSpeechAPI.speech(text: "Hello", voiceID: "ara", apiKey: "test-key", session: session)
        XCTAssertEqual(audio, Data([1, 2, 3]))
        VoiceStubProtocol.handler = { _ in (200, "application/json", Data("{}".utf8)) }
        do {
            _ = try await GrokSpeechAPI.speech(text: "Hello", voiceID: "ara", apiKey: "test-key", session: session)
            XCTFail("JSON must not be played as audio")
        } catch VoiceAPIError.invalidResponse {} catch { XCTFail("Unexpected error: \(error)") }
    }

    func testOpenAIVoicesIncludeEveryDocumentedBuiltin() {
        XCTAssertEqual(Set(SpeechVoice.openAI.map(\.id)), Set([
            "alloy", "ash", "ballad", "coral", "echo", "fable", "nova",
            "onyx", "sage", "shimmer", "verse", "marin", "cedar"
        ]))
    }

    func testOpenAIKeyNormalizationPreservesStoredKeyAndProjectKey() {
        let suite = "OpenAIKeyTests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let pasted = " \n sk-proj-example-test-key \r\n"
        defaults.set(pasted, forKey: "openAIApiKey")
        XCTAssertEqual(OpenAICredentials.savedKey(defaults: defaults), "sk-proj-example-test-key")
        XCTAssertEqual(defaults.string(forKey: "openAIApiKey"), pasted)
        XCTAssertEqual(OpenAICredentials.normalized("sk-valid"), "sk-valid")
    }

    func testOpenAIKeyCheckUsesSavedKeyWithoutGeneratingContent() async throws {
        VoiceStubProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/models")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            return (401, "application/json", Data())
        }
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        let message = try await OpenAICredentials.test(apiKey: " sk-test\n", session: session)
        XCTAssertTrue(message.contains("rejected"))
        XCTAssertFalse(message.contains("sk-test"))
        VoiceStubProtocol.handler = { _ in
            XCTFail("Do not send a request with an empty key")
            return (401, "application/json", Data())
        }
        let missing = try await OpenAICredentials.test(apiKey: " \n", session: session)
        XCTAssertTrue(missing.contains("No OpenAI API key"))
    }

    @MainActor func testSpeechCompletionDeliversSnapshotOnlyOnce() {
        let recognizer = SpeechRecognizer(requestPermissions: false)
        var completed: [String] = []
        recognizer.setOnTimeoutHandler { text in completed.append(text) }
        recognizer.transcript = "  First question\n"
        recognizer.finishTranscribing()
        XCTAssertEqual(completed, ["First question"])
        XCTAssertEqual(recognizer.transcript, "")
        // A late final result/timeout must not send the just-finished turn twice.
        recognizer.finishTranscribing()
        XCTAssertEqual(completed, ["First question"])
        recognizer.transcript = "Second question"
        recognizer.finishTranscribing()
        XCTAssertEqual(completed, ["First question", "Second question"])
    }

    @MainActor func testEmptySpeechDoesNotSubmit() {
        let recognizer = SpeechRecognizer(requestPermissions: false)
        recognizer.setOnTimeoutHandler { _ in XCTFail("Empty speech must not submit") }
        recognizer.transcript = " \n"
        recognizer.finishTranscribing()
    }

    func testProviderModelListsUseSeparateAuthenticatedEndpoints() async throws {
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        for provider in [ModelAPIProvider.openAI, .grok] {
            VoiceStubProtocol.handler = { request in
                XCTAssertEqual(request.url, provider.url)
                XCTAssertEqual(request.httpMethod, "GET")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer model-test-key")
                return (200, "application/json", Data(#"{"data":[{"id":"model-b"},{"id":"model-a"},{"id":"model-a"},{"id":""}]}"#.utf8))
            }
            let models = try await ProviderModelsAPI.fetch(provider: provider, apiKey: " model-test-key\n", session: session)
            XCTAssertEqual(models, ["model-a", "model-b"])
        }
    }

    func testModelListMissingKeyAndPermissionErrors() async {
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        VoiceStubProtocol.handler = { _ in
            XCTFail("An empty key must not make a request")
            return (500, "application/json", Data())
        }
        do {
            _ = try await ProviderModelsAPI.fetch(provider: .openAI, apiKey: " ", session: session)
            XCTFail("Expected missing key")
        } catch ModelListError.missingKey {} catch { XCTFail("Unexpected error: \(error)") }
        VoiceStubProtocol.handler = { _ in (403, "application/json", Data("{}".utf8)) }
        do {
            _ = try await ProviderModelsAPI.fetch(provider: .grok, apiKey: "key", session: session)
            XCTFail("Expected permission error")
        } catch ModelListError.http(403) {} catch { XCTFail("Unexpected error: \(error)") }
    }

    @MainActor func testModelListDiscardedWhenKeyIsCleared() async {
        let session = voiceSession()
        defer { session.invalidateAndCancel() }
        VoiceStubProtocol.handler = { _ in (200, "application/json", Data(#"{"data":[{"id":"old-account-model"}]}"#.utf8)) }
        let list = ProviderModelList()
        let oldLoad = Task { await list.load(provider: .openAI, apiKey: "old-key", session: session) }
        await Task.yield()
        await list.load(provider: .openAI, apiKey: "", session: session)
        await oldLoad.value
        XCTAssertNil(list.models)
        XCTAssertNil(list.errorMessage)
        XCTAssertFalse(list.isLoading)
    }

    func testCustomModelNamesAreTrimmedAndEmptyNamesUseDefaults() {
        XCTAssertEqual(resolvedModel(grokEnabled: false, defaultOpenAIModel: "default-model", overrideOpenAIModel: " custom-model\n", grokOverrideModel: ""), "custom-model")
        XCTAssertEqual(resolvedModel(grokEnabled: false, defaultOpenAIModel: "default-model", overrideOpenAIModel: " ", grokOverrideModel: ""), "default-model")
        XCTAssertEqual(resolvedModel(grokEnabled: true, defaultOpenAIModel: "unused", overrideOpenAIModel: "", grokOverrideModel: " grok-custom "), "grok-custom")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

private final class VoiceStubProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (Int, String, Data))!
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, contentType, data) = Self.handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": contentType])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

# Testing Guide - OS One

Complete testing documentation for OS One offline voice AI assistant.

## 📋 Table of Contents

- [Overview](#overview)
- [Test Types](#test-types)
- [Running Tests](#running-tests)
- [Test Coverage](#test-coverage)
- [CI/CD Pipeline](#cicd-pipeline)
- [Writing Tests](#writing-tests)
- [Performance Benchmarks](#performance-benchmarks)
- [Troubleshooting](#troubleshooting)

## Overview

OS One has a comprehensive test suite ensuring quality across all components:

- **Unit Tests** - Test individual components in isolation (>80% coverage)
- **UI Tests** - Test user interface flows with XCUITest
- **Integration Tests** - Test complete voice pipeline (VAD → STT → LLM → TTS)
- **Performance Tests** - Benchmark inference speed, latency, memory usage
- **Stress Tests** - Verify stability under load

### Test Statistics

```
Total Tests: 100+
Unit Tests: 50+
UI Tests: 25+
Integration Tests: 15+
Performance Tests: 10+
Code Coverage Target: >80%
```

## Test Types

### 1. Unit Tests

Test individual components in isolation:

#### LocalLLMManagerTests
- Model loading/unloading
- Prompt template generation
- Token generation
- Error handling
- Memory management

**Location:** `OS One Tests/LocalLLMManagerTests.swift`

**Run:**
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/LocalLLMManagerTests"
```

#### VoiceActivityDetectorTests
- Audio buffer processing
- State machine transitions
- Energy level calculations
- Callback triggers
- Performance metrics

**Location:** `OS One Tests/VoiceActivityDetectorTests.swift`

#### DeviceCapabilityDetectorTests
- RAM detection
- Performance tier classification
- Model recommendations
- Device identification

**Location:** `OS One Tests/DeviceCapabilityDetectorTests.swift`

#### UIModeManagerTests
- Mode switching (Clean/Flexible/Pro)
- Drawer controls
- Feature flags
- Persistence

**Location:** `OS One Tests/UIModeManagerTests.swift`

### 2. UI Tests

Test user interface flows using XCUITest:

#### Mode Switching Tests
- Open mode selector
- Switch between Clean/Flexible/Pro modes
- Verify UI changes
- Test drawer expansion/collapse

#### Settings Tests
- Toggle offline mode
- Select models
- Adjust VAD sensitivity
- Configure TTS settings

#### Navigation Tests
- Navigate to conversation archive
- Delete conversations
- Handle back navigation

#### Accessibility Tests
- VoiceOver compatibility
- Dynamic Type support
- Semantic labels

**Location:** `OS One UI Tests/OSOneUITests.swift`

**Run:**
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One UI Tests"
```

### 3. Integration Tests

Test complete voice pipeline integration:

#### VAD → STT Integration
- VAD triggers recognition
- Silence detection stops recognition
- Audio buffer handoff

#### STT → LLM Integration
- Transcript feeds to LLM
- Context maintenance across turns
- Conversation history

#### LLM → TTS Integration
- Response spoken via TTS
- Streaming support
- Interruption handling

#### Full Pipeline Tests
- Complete offline conversation flow
- Multi-turn conversations
- End-to-end latency
- Error recovery

**Location:** `OS One Tests/VoicePipelineIntegrationTests.swift`

**Run:**
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/VoicePipelineIntegrationTests"
```

### 4. Performance Tests

Benchmark critical performance metrics:

#### Model Performance
- Load time (target: <5s for 3B model)
- First token latency (target: <250ms)
- Token throughput (target: >18 tok/s)
- Memory usage

#### VAD Performance
- Processing latency (target: <10ms)
- CPU usage (target: <5%)
- Memory footprint (target: <50MB)

#### TTS Performance
- Initialization time (target: <100ms)
- Speech latency (target: <200ms)

#### End-to-End Performance
- Full conversation cycle (target: <5s)
- Concurrent request handling

**Location:** `OS One Tests/PerformanceBenchmarkTests.swift`

**Run:**
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/PerformanceBenchmarkTests"
```

## Running Tests

### Quick Start

Run all tests:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0"
```

### Xcode UI

1. Open `OS One.xcodeproj` in Xcode
2. Press `⌘ + U` to run all tests
3. Or use Test Navigator (`⌘ + 6`) to run specific tests

### Command Line

Run specific test file:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/LocalLLMManagerTests" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0"
```

Run specific test method:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/LocalLLMManagerTests/testModelTypeProperties" \
  -destination "platform=iOS Simulator,name=iPhone 15 Pro,OS=17.0"
```

### Test Filtering

Run only unit tests:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests"
```

Run only UI tests:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One UI Tests"
```

Skip specific tests:
```bash
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -skip-testing:"OS One Tests/PerformanceBenchmarkTests"
```

## Test Coverage

### Viewing Coverage

#### Xcode
1. Run tests with coverage: `⌘ + U`
2. Open Report Navigator (`⌘ + 9`)
3. Select latest test run
4. Click "Coverage" tab

#### Command Line
```bash
# Run tests with coverage
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult

# View coverage report
xcrun xccov view --report --json TestResults.xcresult > coverage.json
```

### Coverage Targets

| Component | Target | Current |
|-----------|--------|---------|
| LocalLLMManager | >80% | TBD |
| VoiceActivityDetector | >80% | TBD |
| DeviceCapabilityDetector | >90% | TBD |
| UIModeManager | >85% | TBD |
| SpeechRecognizer | >75% | TBD |
| NativeTTSManager | >80% | TBD |
| **Overall** | **>80%** | **TBD** |

### Coverage Report

Generate HTML coverage report:
```bash
# Install xcov
gem install xcov

# Generate report
xcov \
  --project "OS One.xcodeproj" \
  --scheme "OS One" \
  --output_directory coverage_report
```

## CI/CD Pipeline

### GitHub Actions Workflows

#### 1. Main CI Pipeline (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main`, `develop`, or `claude/**` branches
- Pull requests to `main` or `develop`

**Jobs:**
- ✅ SwiftLint (code quality)
- ✅ Unit tests
- ✅ UI tests
- ✅ Integration tests
- ✅ Code coverage (>80%)
- ✅ iOS build (Debug + Release)
- ✅ macOS build (Debug + Release)
- ✅ Static analysis

**Duration:** ~15-20 minutes

#### 2. Nightly Benchmarks (`.github/workflows/nightly-benchmarks.yml`)

**Triggers:**
- Scheduled: Daily at 2 AM UTC
- Manual: workflow_dispatch

**Jobs:**
- 📊 Performance benchmarks
- 🔍 Memory leak detection
- 💪 Stress tests
- 📱 Device-specific tests (iPhone 15/14/13 Pro, iPad Pro)
- 📈 Performance regression detection

**Duration:** ~45-60 minutes

#### 3. Release Pipeline (`.github/workflows/release.yml`)

**Triggers:**
- Version tags (`v*.*.*`)
- Manual: workflow_dispatch

**Jobs:**
- ✅ Validate version
- ✅ Run full test suite
- 📱 Build for TestFlight
- 🏪 Build for App Store (optional)
- 📦 Create GitHub release
- 📢 Notify team

**Duration:** ~30-40 minutes

### Running CI Locally

Install Act (GitHub Actions local runner):
```bash
brew install act
```

Run CI locally:
```bash
# Run main CI
act -j unit-tests

# Run specific job
act -j code-coverage

# Run with secrets
act --secret-file .secrets
```

### CI Requirements

**Secrets needed:**
- `BUILD_CERTIFICATE_BASE64` - iOS distribution certificate
- `P12_PASSWORD` - Certificate password
- `KEYCHAIN_PASSWORD` - Keychain password
- `PROVISIONING_PROFILE_BASE64` - Provisioning profile
- `APPLE_ID` - Apple Developer account
- `APP_SPECIFIC_PASSWORD` - App-specific password
- `TEAM_ID` - Apple Team ID

## Writing Tests

### Unit Test Template

```swift
import XCTest
@testable import OS_One

final class MyComponentTests: XCTestCase {

    var sut: MyComponent!  // System Under Test

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = MyComponent()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Tests

    func testComponentInitialization() {
        // Given: Initial state
        // When: Component is created
        // Then: Assert expected state
        XCTAssertNotNil(sut)
    }

    func testAsyncOperation() async throws {
        // Given
        let input = "test"

        // When
        let result = try await sut.performAsync(input)

        // Then
        XCTAssertEqual(result, "expected")
    }
}
```

### UI Test Template

```swift
import XCTest

final class MyUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    func testUserFlow() {
        // Navigate
        let button = app.buttons["myButton"]
        XCTAssertTrue(button.exists)

        // Interact
        button.tap()

        // Verify
        let label = app.staticTexts["expectedLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 2))
    }
}
```

### Best Practices

1. **Follow AAA Pattern:**
   - Arrange: Set up test conditions
   - Act: Execute the operation
   - Assert: Verify the result

2. **Test Names:**
   - Use descriptive names: `testVADDetectsSpeechAboveThreshold`
   - Start with `test`
   - Include expected behavior

3. **One Assertion Per Test:**
   - Focus on single behavior
   - Makes failures clearer

4. **Use Test Doubles:**
   - Mocks for external dependencies
   - Stubs for controlled data
   - Spies for verification

5. **Async Testing:**
   ```swift
   func testAsync() async throws {
       let result = try await asyncOperation()
       XCTAssertEqual(result, expected)
   }
   ```

6. **Expectations:**
   ```swift
   let expectation = XCTestExpectation(description: "Callback called")

   component.onComplete = {
       expectation.fulfill()
   }

   await fulfillment(of: [expectation], timeout: 5.0)
   ```

## Performance Benchmarks

### Device Baselines

#### iPhone 12 Pro Max (6GB RAM, A14 Bionic) - Baseline
```
Model Load Time: ~5s (Qwen 2.5 3B @ 4-bit)
First Token Latency: <250ms
Token Throughput: 18-25 tok/s
VAD Processing: <10ms per buffer
TTS Latency: <200ms
End-to-End: <5s
Memory Usage: ~2.5GB peak
```

#### iPhone 15 Pro (8GB RAM, A17 Pro)
```
Model Load Time: ~3s (Qwen 3 4B @ 4-bit)
First Token Latency: <300ms
Token Throughput: 15-20 tok/s
VAD Processing: <5ms per buffer
TTS Latency: <150ms
End-to-End: <3s
Memory Usage: ~3GB peak
```

#### iPad Pro M2 (8GB RAM)
```
Model Load Time: ~4s (Qwen 3 4B @ 8-bit)
First Token Latency: <200ms
Token Throughput: 20-25 tok/s
End-to-End: <2s
Memory Usage: ~3.5GB peak
```

### Running Benchmarks

```bash
# Run all performance tests
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/PerformanceBenchmarkTests"

# Device-specific benchmark
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -only-testing:"OS One Tests/PerformanceBenchmarkTests/testPerformanceOnCurrentDevice"
```

### Benchmark Metrics

| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Model Load | <5s | >7s | >10s |
| First Token | <250ms | >500ms | >1s |
| Throughput | >18 tok/s | <12 tok/s | <8 tok/s |
| VAD Latency | <10ms | >20ms | >50ms |
| TTS Latency | <200ms | >500ms | >1s |
| Memory Peak | <3GB | >4GB | >5GB |

## Troubleshooting

### Common Issues

#### Tests Fail on CI but Pass Locally

**Solution:**
- Check Xcode version matches CI
- Verify simulator OS version
- Clear DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`

#### Model Not Loading in Tests

**Solution:**
- Models are not included in test bundle by default
- Use `XCTSkip` for tests requiring models:
  ```swift
  guard modelExists else {
      throw XCTSkip("Model files not available")
  }
  ```

#### UI Tests Timing Out

**Solution:**
- Increase timeout: `waitForExistence(timeout: 10)`
- Add launch arguments for faster animation:
  ```swift
  app.launchArguments = ["--uitesting", "--disable-animations"]
  ```

#### Memory Leaks Detected

**Solution:**
- Run with Instruments (Leaks template)
- Check for retain cycles
- Use `[weak self]` in closures

#### Code Coverage Below Target

**Solution:**
- Identify uncovered code:
  ```bash
  xcrun xccov view --file-list TestResults.xcresult
  ```
- Add tests for missing branches
- Remove dead code

### Debug Test Failures

Enable test debugging:
```swift
// In test setup
if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
    print("Running under XCTest")
}
```

Attach debugger:
1. Set breakpoint in test
2. Run test with `⌘ + U`
3. Debugger stops at breakpoint

View test logs:
```bash
# After running tests
xcrun simctl spawn booted log show --predicate 'process == "OS One"' --last 1h
```

## Continuous Improvement

### Adding New Tests

1. **Identify untested code:**
   ```bash
   xcrun xccov view --file-list TestResults.xcresult
   ```

2. **Write test:**
   - Follow templates above
   - Use descriptive names
   - Add to appropriate test file

3. **Run locally:**
   ```bash
   xcodebuild test -only-testing:"OS One Tests/NewTest"
   ```

4. **Verify in CI:**
   - Create PR
   - Check CI passes
   - Review coverage change

### Performance Regression Detection

Monitor benchmarks over time:
```bash
# Compare with baseline
python3 scripts/compare_benchmarks.py \
  --current BenchmarkResults.xcresult \
  --baseline baseline_results.json
```

Alert on regression >10%:
- First token latency increase
- Token throughput decrease
- Memory usage increase

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [XCUITest Guide](https://developer.apple.com/documentation/xctest/user_interface_tests)
- [Testing Guide (Apple)](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
- [GitHub Actions for iOS](https://docs.github.com/en/actions/guides/building-and-testing-swift)

---

**Last Updated:** 2025-11-23
**Test Suite Version:** 1.0.0
**Maintained By:** OS One Development Team

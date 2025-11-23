# OS One - Offline Mode Testing Guide

Comprehensive testing guide for the fully offline voice AI assistant implementation.

## Table of Contents
- [Pre-Testing Checklist](#pre-testing-checklist)
- [Component Testing](#component-testing)
- [Integration Testing](#integration-testing)
- [Performance Testing](#performance-testing)
- [Edge Cases](#edge-cases)
- [Acceptance Criteria](#acceptance-criteria)

## Pre-Testing Checklist

### Environment Setup
- [ ] iOS 17.0+ or macOS 14.0+ installed
- [ ] Xcode 15.0+ with project building successfully
- [ ] MLX Swift dependencies installed
- [ ] At least one local model downloaded and converted
- [ ] Microphone permissions granted
- [ ] Speech recognition permissions granted

### Device Recommendations
- **Primary:** iPhone 15 Pro (A17 Pro chip)
- **Alternative:** iPad Pro M2, MacBook M1+

### Required Files
Verify all new files are in the Xcode project:
- [x] VoiceActivityDetector.swift
- [x] LocalLLMManager.swift
- [x] AudioWaveformView.swift
- [x] ModelDownloadManager.swift
- [x] NativeTTSManager.swift
- [x] Modified: SpeechRecognizer.swift
- [x] Modified: HomeView.swift
- [x] Modified: SettingsView.swift

## Component Testing

### 1. Voice Activity Detection (VAD)

#### Test 1.1: Basic VAD Detection
**Objective:** Verify VAD detects speech start and end

**Steps:**
1. Open OS One
2. Enable offline mode in settings
3. Toggle "Voice Activity Detection" ON
4. Toggle "Show waveform" ON
5. Speak a simple phrase: "Hello"

**Expected Results:**
- ✅ Waveform appears when speaking
- ✅ Waveform shows activity (bars moving)
- ✅ Speech automatically stops after 1-2 seconds of silence
- ✅ Transcript appears: "Hello"

**Pass Criteria:** All expected results met

---

#### Test 1.2: VAD Sensitivity
**Objective:** Verify VAD sensitivity adjustment works

**Steps:**
1. Settings → Offline mode
2. Set VAD Sensitivity to 30%
3. Speak quietly
4. Set VAD Sensitivity to 70%
5. Speak quietly again

**Expected Results:**
- ✅ At 30%: Speech may not be detected (low sensitivity)
- ✅ At 70%: Speech is detected easily (high sensitivity)
- ✅ Waveform reflects sensitivity changes

**Pass Criteria:** Noticeable difference in detection between 30% and 70%

---

#### Test 1.3: Background Noise Handling
**Objective:** Verify VAD adapts to background noise

**Steps:**
1. Enable VAD with sensitivity 50%
2. Test in quiet room
3. Play background music (moderate volume)
4. Speak over the music

**Expected Results:**
- ✅ Quiet room: Clean detection
- ✅ With music: Still detects speech (adaptive threshold)
- ✅ No false triggers from music alone

**Pass Criteria:** VAD distinguishes speech from background noise

---

### 2. Local LLM Integration

#### Test 2.1: Model Loading
**Objective:** Verify local model loads successfully

**Steps:**
1. Settings → Offline mode → Enable offline mode
2. Select "Qwen 2.5 1.5B" (or your downloaded model)
3. Toggle offline mode button on home screen
4. Wait for status message

**Expected Results:**
- ✅ Status shows "loading model..."
- ✅ Status changes to "model loaded" within 5-10 seconds
- ✅ No crashes or errors
- ✅ Memory usage acceptable (<2GB for 1.5B model)

**Pass Criteria:** Model loads successfully without errors

---

#### Test 2.2: Basic Inference
**Objective:** Verify model generates responses

**Steps:**
1. Ensure model is loaded (Test 2.1)
2. Ask: "What is 2 plus 2?"
3. Wait for response

**Expected Results:**
- ✅ Status shows "thinking"
- ✅ Response generated within 5-10 seconds
- ✅ Response is relevant: "Four" or "2 plus 2 is 4"
- ✅ Status shows "vocalising"
- ✅ Response spoken via TTS

**Pass Criteria:** Correct answer within 10 seconds

---

#### Test 2.3: Conversation Context
**Objective:** Verify model maintains conversation context

**Steps:**
1. Ask: "My name is Alice"
2. Wait for response
3. Ask: "What is my name?"

**Expected Results:**
- ✅ First response acknowledges name: "Nice to meet you, Alice"
- ✅ Second response recalls name: "Your name is Alice"
- ✅ Conversation history maintained

**Pass Criteria:** Model correctly recalls previous context

---

#### Test 2.4: Persona Adherence
**Objective:** Verify model follows selected persona

**Steps:**
1. Settings → Select "Samantha" persona
2. Ask: "How are you feeling today?"
3. Settings → Select "KITT" persona
4. Delete conversation
5. Ask same question

**Expected Results:**
- ✅ Samantha: Warm, empathetic response
- ✅ KITT: Formal, precise response
- ✅ Different tone between personas

**Pass Criteria:** Noticeable personality differences

---

### 3. Native Text-to-Speech

#### Test 3.1: Basic TTS
**Objective:** Verify native TTS works

**Steps:**
1. Settings → Offline mode → Enable
2. Ensure "Eleven Labs voice" is OFF
3. Ask a simple question
4. Listen to response

**Expected Results:**
- ✅ Voice is clear and understandable
- ✅ Natural pronunciation
- ✅ Appropriate voice for persona
- ✅ No robotic artifacts

**Pass Criteria:** TTS is intelligible and natural

---

#### Test 3.2: Speech Rate Adjustment
**Objective:** Verify speech rate control

**Steps:**
1. Settings → Speech Rate: 20%
2. Listen to a response
3. Settings → Speech Rate: 80%
4. Listen to another response

**Expected Results:**
- ✅ At 20%: Very slow speech
- ✅ At 80%: Fast speech
- ✅ Pitch remains consistent
- ✅ Still intelligible at both extremes

**Pass Criteria:** Noticeable speed difference, both intelligible

---

#### Test 3.3: Speech Pitch Adjustment
**Objective:** Verify speech pitch control

**Steps:**
1. Settings → Speech Pitch: 0.7x
2. Listen to response
3. Settings → Speech Pitch: 1.5x
4. Listen to response

**Expected Results:**
- ✅ At 0.7x: Lower pitch
- ✅ At 1.5x: Higher pitch
- ✅ Rate remains consistent
- ✅ Still natural sounding

**Pass Criteria:** Noticeable pitch difference, still natural

---

### 4. Speech Recognition

#### Test 4.1: On-Device Recognition
**Objective:** Verify on-device speech recognition works

**Steps:**
1. Settings → Toggle "On-device speech recognition" ON
2. Turn on Airplane Mode
3. Speak: "Testing on-device recognition"

**Expected Results:**
- ✅ Transcript appears correctly
- ✅ No internet connection required
- ✅ Partial results shown in real-time
- ✅ Final transcript is accurate

**Pass Criteria:** Accurate transcription without internet

---

#### Test 4.2: Multiple Languages
**Objective:** Verify multi-language support (if configured)

**Steps:**
1. iOS Settings → General → Language & Region
2. Add Spanish/French/German
3. Speak in that language

**Expected Results:**
- ✅ Recognizes alternative language
- ✅ Transcript in correct language
- ✅ Model responds appropriately

**Pass Criteria:** Recognizes at least English correctly

---

### 5. Audio Waveform Visualization

#### Test 5.1: Waveform Display
**Objective:** Verify waveform shows audio activity

**Steps:**
1. Settings → Toggle "Show waveform" ON
2. Return to home screen
3. Speak continuously for 5 seconds

**Expected Results:**
- ✅ Waveform visible on home screen
- ✅ Bars animate in real-time
- ✅ Height correlates with volume
- ✅ Color changes when speaking (green) vs listening (orange)

**Pass Criteria:** Waveform accurately reflects audio input

---

#### Test 5.2: Waveform Performance
**Objective:** Verify waveform doesn't impact performance

**Steps:**
1. Enable waveform
2. Monitor frame rate (Xcode: Debug → View Debugging → Show FPS)
3. Speak for extended period (30 seconds)

**Expected Results:**
- ✅ Maintains 60 FPS (or device maximum)
- ✅ No lag in UI
- ✅ Smooth animation

**Pass Criteria:** >50 FPS consistently

---

## Integration Testing

### Test 6: Full Conversation Flow

**Objective:** Verify end-to-end conversation works offline

**Scenario:** Complete conversation without internet

**Steps:**
1. Enable Airplane Mode
2. Enable offline mode in OS One
3. Load local model (Qwen 2.5 1.5B)
4. Enable VAD
5. Start conversation:
   - User: "Hello, how are you?"
   - [Wait for AI response]
   - User: "What's the weather like?" (should admit no internet)
   - [Wait for AI response]
   - User: "Tell me a joke"
   - [Wait for AI response]

**Expected Results:**
- ✅ All steps work without internet
- ✅ VAD detects speech start/stop automatically
- ✅ Transcription is accurate
- ✅ Model generates relevant responses
- ✅ TTS speaks responses clearly
- ✅ Conversation feels natural (minimal delays)

**Timing Benchmarks:**
- Speech recognition: <1 second to transcript
- LLM inference: 3-8 seconds for response
- TTS playback: Starts immediately
- Total turn-around: <10 seconds

**Pass Criteria:** All responses within 10 seconds, no internet needed

---

### Test 7: Mode Switching

**Objective:** Verify switching between online/offline modes

**Steps:**
1. Start in online mode (OpenAI)
2. Ask: "What is the capital of France?"
3. Toggle offline mode ON
4. Wait for model to load
5. Ask: "What is the capital of Spain?"
6. Toggle offline mode OFF
7. Ask: "What is the capital of Italy?"

**Expected Results:**
- ✅ Online: Uses OpenAI API (faster, more knowledgeable)
- ✅ Offline: Uses local model (slower, but works)
- ✅ Smooth transitions between modes
- ✅ Conversation history preserved
- ✅ Appropriate status messages shown

**Pass Criteria:** Both modes work correctly, seamless switching

---

## Performance Testing

### Test 8: Memory Usage

**Objective:** Verify memory usage is acceptable

**Setup:** Xcode → Debug → Memory Report

**Tests:**

| Scenario | Expected Memory | Actual | Pass/Fail |
|----------|----------------|--------|-----------|
| App launch | <200 MB | ___ MB | ___ |
| Model loaded (1.5B) | <1.5 GB | ___ GB | ___ |
| During inference | <2.0 GB | ___ GB | ___ |
| After 10 turns | <2.5 GB | ___ GB | ___ |
| Model loaded (3B) | <3.0 GB | ___ GB | ___ |

**Pass Criteria:** Memory stays within expected limits

---

### Test 9: Battery Impact

**Objective:** Measure battery consumption

**Steps:**
1. Fully charge device
2. Settings → Battery → Show battery percentage
3. Note starting battery %
4. Have 10-minute conversation (offline mode)
5. Note ending battery %

**Expected Results:**
- ✅ Battery drain <15% for 10 minutes
- ✅ Device doesn't overheat (temp <40°C)
- ✅ Comparable to normal app usage

**Pass Criteria:** <15% battery drain per 10 minutes

---

### Test 10: Inference Speed

**Objective:** Benchmark LLM inference speed

**Setup:**
- Model: Qwen 2.5 1.5B (q4)
- Device: iPhone 15 Pro
- Prompt: "Write a haiku about AI"

**Metrics:**

| Metric | Expected | Actual | Pass/Fail |
|--------|----------|--------|-----------|
| First token latency | <1s | ___ s | ___ |
| Tokens per second | 10-20 | ___ | ___ |
| Total time (50 tokens) | 3-5s | ___ s | ___ |

**Pass Criteria:** Meets expected performance

---

## Edge Cases

### Test 11: Error Handling

#### Test 11.1: Model Not Downloaded
**Steps:**
1. Enable offline mode
2. Select model that's not downloaded
3. Toggle offline mode ON

**Expected:**
- ✅ Error message: "Model not downloaded"
- ✅ Prompt to download model
- ✅ No crash

---

#### Test 11.2: Insufficient Storage
**Steps:**
1. Fill device storage (leave <500MB)
2. Try to download 3B model

**Expected:**
- ✅ Error message: "Insufficient storage"
- ✅ Shows required vs available space
- ✅ Suggests clearing space or smaller model

---

#### Test 11.3: Microphone Denied
**Steps:**
1. Settings → Privacy → Microphone → OS One → OFF
2. Try to use voice input

**Expected:**
- ✅ Prompt to enable microphone
- ✅ Deep link to Settings
- ✅ Clear error message

---

#### Test 11.4: Memory Warning
**Steps:**
1. Load 3B model on older device (e.g., iPhone 13)
2. Open many background apps
3. Start conversation

**Expected:**
- ✅ App handles memory warning gracefully
- ✅ Unloads model if necessary
- ✅ Shows "memory warning" message
- ✅ No crash

---

### Test 12: Stress Testing

#### Test 12.1: Long Conversation
**Steps:**
1. Have 50+ turn conversation
2. Monitor memory and performance

**Expected:**
- ✅ Memory growth is bounded
- ✅ Response time remains consistent
- ✅ Conversation history managed properly

---

#### Test 12.2: Rapid Input
**Steps:**
1. Speak immediately after each response (no pauses)
2. Repeat 10 times quickly

**Expected:**
- ✅ Handles rapid input gracefully
- ✅ No queue overflow
- ✅ Responses remain coherent

---

## Acceptance Criteria

### Critical Features (Must Pass)
- [ ] **VAD Detection:** Automatically detects speech start/end
- [ ] **Local LLM:** Generates relevant responses offline
- [ ] **Native TTS:** Speaks responses clearly
- [ ] **On-Device STT:** Transcribes speech without internet
- [ ] **Full Offline:** Entire conversation works with no internet
- [ ] **Performance:** Responses within 10 seconds
- [ ] **Memory:** Stays under 3GB for 3B models
- [ ] **Stability:** No crashes during 30-minute session

### Important Features (Should Pass)
- [ ] **Waveform:** Visual feedback during speech
- [ ] **Sensitivity Control:** VAD sensitivity adjustable
- [ ] **Voice Control:** TTS rate and pitch adjustable
- [ ] **Persona Adherence:** Model follows selected persona
- [ ] **Context Retention:** Remembers conversation history
- [ ] **Mode Switching:** Smooth online/offline transitions

### Nice-to-Have Features (May Pass)
- [ ] **Multi-Language:** Supports multiple languages
- [ ] **Model Download:** In-app model downloading
- [ ] **Battery Optimization:** <10% battery per 10 minutes
- [ ] **Advanced VAD:** Background noise filtering

## Test Report Template

```markdown
# OS One Offline Mode Test Report

**Date:** YYYY-MM-DD
**Tester:** [Name]
**Device:** [Model] ([iOS/macOS version])
**Model:** [Local model used]

## Test Summary
- Total Tests: __
- Passed: __
- Failed: __
- Skipped: __

## Component Testing
- [ ] VAD: ___/3 passed
- [ ] LLM: ___/4 passed
- [ ] TTS: ___/3 passed
- [ ] STT: ___/2 passed
- [ ] Waveform: ___/2 passed

## Integration Testing
- [ ] Full conversation flow: Pass/Fail
- [ ] Mode switching: Pass/Fail

## Performance Testing
- [ ] Memory usage: Pass/Fail
- [ ] Battery impact: Pass/Fail
- [ ] Inference speed: Pass/Fail

## Edge Cases
- [ ] Error handling: ___/4 passed
- [ ] Stress testing: ___/2 passed

## Critical Issues Found
1. [Issue description]
2. [Issue description]

## Notes
[Additional observations, suggestions, etc.]
```

## Automated Testing (Future)

### Unit Tests
```swift
// VoiceActivityDetectorTests.swift
func testVADDetectsSpeech() {
    let vad = VoiceActivityDetector()
    let expectation = XCTestExpectation(description: "Speech detected")

    vad.onSpeechStart = {
        expectation.fulfill()
    }

    // Simulate audio buffer with speech
    let buffer = createTestAudioBuffer(withSpeech: true)
    vad.processAudioBuffer(buffer)

    wait(for: [expectation], timeout: 1.0)
}
```

### Integration Tests
```swift
// OfflineModeTests.swift
func testFullOfflineConversation() async throws {
    let app = XCUIApplication()
    app.launch()

    // Enable offline mode
    app.buttons["wifi"].tap()

    // Wait for model load
    XCTAssertTrue(app.staticTexts["model loaded"].waitForExistence(timeout: 10))

    // Simulate voice input
    // (Requires additional test infrastructure)
}
```

## Continuous Testing

### Daily
- [ ] Smoke test: Basic conversation flow
- [ ] Memory monitoring
- [ ] Crash reports review

### Weekly
- [ ] Full test suite execution
- [ ] Performance benchmarks
- [ ] Battery impact measurement

### Before Release
- [ ] Complete acceptance criteria
- [ ] All critical tests passing
- [ ] Test on multiple devices
- [ ] 48-hour soak test (app running continuously)

## Resources

- **Xcode Instruments:** For performance profiling
- **Console.app:** For system logs and crash reports
- **TestFlight:** For beta testing on real devices
- **Firebase Performance:** For production monitoring (optional)

---

**Last Updated:** 2025-11-23
**Version:** 1.0
**Status:** Ready for Testing

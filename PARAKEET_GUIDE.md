# Parakeet STT & Global Dictation Guide - OS One (macOS)

Advanced speech-to-text and system-wide dictation features for macOS.

## 🎤 Overview

OS One now supports two powerful macOS-exclusive features:

1. **NVIDIA Parakeet CTC** - High-quality speech-to-text alternative
2. **Global Dictation** - System-wide voice input via Fn key

These features work together to provide:
- Better transcription accuracy than iOS Speech Recognition
- System-wide dictation in any app (Chrome, Notes, Slack, VS Code, etc.)
- Offline-capable speech recognition
- Customizable activation keys

---

## 🦜 NVIDIA Parakeet CTC

### What is Parakeet?

Parakeet CTC (Connectionist Temporal Classification) is NVIDIA's state-of-the-art ASR (Automatic Speech Recognition) model. It provides:

- **High Accuracy**: Better than iOS Speech Recognition
- **Offline**: Runs locally on your Mac
- **Fast**: Optimized for real-time transcription
- **Flexible**: Supports 30-second audio context

### Models Available

| Model | Version | Size | Best For |
|-------|---------|------|----------|
| **parakeet-ctc-0.6-v3** | Latest | ~620MB | Most users (default) |
| **parakeet-ctc-0.6-v2** | Stable | ~600MB | Conservative users |

### Installation

#### Option 1: Local Inference (Recommended)

1. **Install Python dependencies**
   ```bash
   pip install onnxruntime torch transformers
   ```

2. **Download the model**
   ```bash
   # From Hugging Face
   git clone https://huggingface.co/nvidia/parakeet-ctc-0.6
   ```

3. **Convert to ONNX or CoreML**
   ```bash
   # Convert PyTorch model to ONNX
   python convert_to_onnx.py parakeet-ctc-0.6
   ```

4. **Start local inference server**
   ```bash
   # Run on localhost:8000
   python inference_server.py --port 8000
   ```

#### Option 2: API Endpoint

Use a pre-configured inference server:
- Local: `http://localhost:8000`
- Remote: `https://your-server.com/api`

### Configuration

**In OS One Settings:**

1. Open Settings (⌘,)
2. Scroll to "**parakeet speech-to-text (macOS)**"
3. Toggle "**Use Parakeet STT**" ON
4. Select model: CTC 0.6 v3 (Latest)
5. Set endpoint: `http://localhost:8000`
6. Verify connection status (green = connected)

**Settings Stored:**
```swift
useParakeetSTT: Bool
parakeetModel: String
parakeetEndpoint: String
```

### API Interface

The inference server should implement:

**Endpoint:** `POST /transcribe`

**Request:**
- Content-Type: `application/octet-stream`
- Body: Raw audio data (Float32, 16kHz, mono)

**Response:**
```json
{
  "text": "transcribed text here",
  "confidence": 0.95
}
```

### Troubleshooting

**Connection Failed:**
```
Status: ○ not running
```

**Solutions:**
1. Start inference server: `python inference_server.py`
2. Check port: `lsof -i :8000`
3. Verify endpoint URL in settings

**Poor Accuracy:**
- Ensure 16kHz sample rate
- Check microphone quality
- Reduce background noise
- Use Parakeet v3 (latest model)

**Slow Performance:**
- Use GPU acceleration (CUDA/Metal)
- Reduce audio buffer size
- Switch to ONNX Runtime
- Use smaller context window

---

## ⌨️ Global Dictation

### What is Global Dictation?

System-wide voice input that works in ANY macOS application. Similar to Whisper Flow and Super Whisper apps.

**Features:**
- Press Fn key to start recording
- Release to transcribe and insert text
- Works in Chrome, Slack, Notes, VS Code, Terminal, etc.
- Visual recording indicator
- Customizable activation keys

### Setup

#### 1. Grant Permissions

Global dictation requires **Accessibility** permissions:

1. Open OS One Settings (⌘,)
2. Scroll to "**global dictation (macOS)**"
3. Toggle "**Enable global dictation**" ON
4. Click "**grant permissions**"
5. macOS will open: **System Settings** > **Privacy & Security** > **Accessibility**
6. Enable OS One in the list
7. Restart OS One

#### 2. Choose Activation Key

**Available Options:**

| Option | Behavior | Best For |
|--------|----------|----------|
| **Left Fn Key (Hold)** | Hold to record, release to insert | Quick dictation |
| **Right Fn Key (Hold)** | Same as left, but right Fn | Ergonomic preference |
| **Double Fn Tap (Toggle)** | Double-tap to start/stop | Long dictation |

**Default:** Left Fn Key (Hold)

### Usage

#### Quick Dictation (Hold Mode)

1. Place cursor where you want text
2. **Hold Fn key** - Recording starts
3. Speak your text
4. **Release Fn key** - Transcription happens
5. Text appears at cursor

**Example:**
```
You're in Slack...
Hold Fn → "Hey team, meeting at 3pm" → Release Fn
Result: "Hey team, meeting at 3pm" appears in Slack
```

#### Long Dictation (Toggle Mode)

1. Set hotkey to "Double Fn Tap"
2. Double-tap Fn to start
3. Speak (can be long)
4. Double-tap Fn to stop
5. Text appears at cursor

### How It Works

**Technical Flow:**

```
1. Global Event Monitor
   ↓ (Fn key press detected)
2. Start Audio Recording
   ↓ (16kHz Float32)
3. Audio Buffer Collection
   ↓ (Fn key release)
4. Send to Parakeet / iOS STT
   ↓ (Transcription)
5. Insert via CGEvents
   ↓ (Simulated typing)
6. Text at Cursor
```

**Key Technologies:**
- **CGEventTap**: Global keyboard monitoring
- **AVAudioEngine**: Audio capture
- **Accessibility API**: Text insertion
- **Parakeet/iOS STT**: Speech recognition

### Supported Applications

**Tested & Working:**
- ✅ Google Chrome
- ✅ Safari
- ✅ Slack
- ✅ Discord
- ✅ Notes
- ✅ Pages
- ✅ TextEdit
- ✅ VS Code
- ✅ Xcode
- ✅ Terminal
- ✅ Mail
- ✅ Messages
- ✅ Notion
- ✅ Obsidian

**Known Issues:**
- ❌ Some password fields (security restriction)
- ⚠️ Vim/Emacs (modal editors need special handling)

### Visual Feedback

When recording:
- **Red floating window** appears (top-right)
- Shows "🎤 Recording..."
- Disappears when stopped

### Privacy & Security

**What OS One Can Access:**
- ✅ Keyboard events (only Fn key)
- ✅ Microphone (for transcription)
- ✅ Text insertion (simulated typing)

**What OS One CANNOT Access:**
- ❌ Your keystrokes (only monitors Fn)
- ❌ Other apps' content
- ❌ Passwords or secure fields

**Permissions Required:**
- Accessibility (for global hotkey + text insertion)
- Microphone (for voice recording)

---

## 🔄 Workflow Examples

### Example 1: Coding in VS Code

```
1. Cursor in code comment
2. Hold Fn
3. "This function calculates the fibonacci sequence using dynamic programming"
4. Release Fn
5. Comment appears: // This function calculates the fibonacci sequence using dynamic programming
```

### Example 2: Email in Gmail (Chrome)

```
1. Click in email body
2. Hold Fn
3. "Hi Sarah, thanks for sending the report. I'll review it by Friday and get back to you with feedback. Best, John"
4. Release Fn
5. Full email appears
```

### Example 3: Terminal Command

```
1. Terminal prompt
2. Hold Fn
3. "docker compose up dash d dash dash build"
4. Release Fn
5. Command appears: docker-compose up -d --build
```

**Note:** Punctuation in speech doesn't translate to symbols. Say "dash" not "-".

### Example 4: Slack Message

```
1. Slack message field
2. Hold Fn
3. "Team meeting moved to 3pm in conference room B"
4. Release Fn
5. Message ready to send
```

---

## ⚙️ Advanced Configuration

### Combining with Offline Mode

Use **Parakeet + Global Dictation + Offline Mode** for fully offline system-wide dictation:

**Settings:**
1. Enable Offline Mode
2. Use Parakeet STT (instead of iOS Speech Recognition)
3. Enable Global Dictation
4. Choose Left Fn Key

**Result:** Completely offline, privacy-focused, system-wide voice input!

### Speech Engine Comparison

| Engine | Accuracy | Speed | Offline | Setup |
|--------|----------|-------|---------|-------|
| **iOS Speech Recognition** | Good | Fast | ❌ | None |
| **Parakeet CTC** | Better | Fast | ✅ | Medium |
| **Whisper (OpenAI)** | Best | Slow | ❌ | None |

### Performance Tuning

**For Best Accuracy:**
- Use quiet environment
- Speak clearly and at normal pace
- Use external microphone (better quality)
- Select Parakeet v3 model

**For Best Speed:**
- Use local Parakeet server (not remote)
- Enable GPU acceleration
- Reduce audio buffer size
- Use SSD for model storage

### Customization Ideas

**Custom Hotkey (Future):**
```swift
// Could add: Fn+Space, Fn+D, Fn+M, etc.
// Currently: Left Fn, Right Fn, Double Fn
```

**Context Injection (Future):**
```swift
// Inject context for better accuracy
// E.g., "code mode" for variable names
```

---

## 🐛 Troubleshooting

### Global Dictation Not Working

**Symptom:** Pressing Fn does nothing

**Solutions:**
1. Check accessibility permissions
   - System Settings > Privacy & Security > Accessibility
   - Enable OS One
2. Restart OS One
3. Toggle global dictation off and on
4. Check console for errors: `log stream --predicate 'process == "OS One"'`

### Text Not Inserting

**Symptom:** Recording works, but text doesn't appear

**Solutions:**
1. Check Fn key is released (Hold mode)
2. Ensure cursor is in text field
3. Try clicking in field first
4. Check app isn't blocking text input
5. Try different insertion method (future: AppleScript fallback)

### Poor Transcription

**Symptom:** Wrong words, garbled text

**Solutions:**
1. Use Parakeet instead of iOS STT
2. Check microphone level in System Settings
3. Reduce background noise
4. Speak more clearly
5. Use push-to-talk mode (better audio capture)

### Recording Indicator Not Showing

**Symptom:** No red window during recording

**Solutions:**
1. Check window permissions
2. Restart OS One
3. Window may be off-screen (move to main display)

---

## 📚 API Reference

### ParakeetSTTClient

```swift
class ParakeetSTTClient: ObservableObject {
    @Published var isRecording: Bool
    @Published var isProcessing: Bool
    @Published var lastTranscription: String
    @Published var isModelLoaded: Bool

    func loadModel(_ model: ParakeetModel) async throws
    func startRecording() throws
    func stopRecording() async -> String
    func downloadModel(_ model: ParakeetModel) async throws
}
```

### GlobalHotkeyManager

```swift
class GlobalHotkeyManager: ObservableObject {
    @Published var isEnabled: Bool
    @Published var isRecording: Bool
    @Published var selectedHotkey: HotkeyType

    func start()
    func stop()
    func hasAccessibilityPermissions() -> Bool
    func requestAccessibilityPermissions()
    func insertTextAtCursor(_ text: String)

    var onRecordingStart: (() -> Void)?
    var onRecordingStop: ((String) -> Void)?
}
```

---

## 🎯 Use Cases

### 1. **Developer Workflow**
- Dictate code comments
- Write commit messages
- Document functions
- Fill PR descriptions

### 2. **Content Creation**
- Blog posts in Notion
- Email composition
- Social media posts
- Technical documentation

### 3. **Communication**
- Slack messages
- Discord chat
- Email replies
- Team updates

### 4. **Note-Taking**
- Meeting notes in Obsidian
- Quick capture in Notes
- Journal entries
- Todo items

### 5. **Accessibility**
- Hands-free typing
- Reduced typing strain
- RSI mitigation
- Voice-first workflows

---

## 📊 Comparison with Other Tools

### vs. Whisper Flow / Super Whisper

| Feature | OS One | Whisper Flow | Super Whisper |
|---------|--------|--------------|---------------|
| **Price** | Free | $30 | $25 |
| **Offline** | ✅ (Parakeet) | ❌ | ✅ (Whisper) |
| **Activation** | Fn key | Hotkey | Hotkey |
| **AI Models** | Multiple | Whisper | Whisper |
| **Voice AI** | ✅ Full LLM | ❌ | ❌ |
| **Open Source** | ✅ | ❌ | ❌ |

**OS One Advantages:**
- Full voice AI assistant (not just dictation)
- Multiple STT engines (iOS, Parakeet, future: Whisper)
- Multiple LLM providers (Local, Haiku, Ollama)
- Integrated workflow (dictation → AI → response)
- Free and open source

### vs. macOS Built-in Dictation

| Feature | OS One | macOS Dictation |
|---------|--------|-----------------|
| **Activation** | Fn key | Fn Fn (double-tap) |
| **Offline** | ✅ (Parakeet) | Limited |
| **Accuracy** | Better (Parakeet) | Good |
| **Customization** | ✅ | ❌ |
| **Open Source** | ✅ | ❌ |

---

## 🚀 Future Enhancements

### Planned Features

- [ ] OpenAI Whisper integration (best accuracy)
- [ ] Custom hotkey combinations (Fn+Space, etc.)
- [ ] Context-aware transcription (code mode, email mode)
- [ ] Punctuation command support ("period", "comma")
- [ ] Multi-language support
- [ ] Voice commands ("new line", "undo", "delete")
- [ ] Continuous dictation mode
- [ ] AppleScript fallback for text insertion
- [ ] Clipboard integration
- [ ] History and corrections

### Community Requests

Want a feature? Open an issue: https://github.com/sighmon/os-one/issues

---

## 📖 Resources

**Parakeet CTC:**
- Model: https://huggingface.co/nvidia/parakeet-ctc-0.6
- Paper: https://nvidia.github.io/NeMo/

**Global Hotkeys:**
- macOS Accessibility: https://developer.apple.com/documentation/accessibility
- CGEventTap: https://developer.apple.com/documentation/coregraphics/cgeventtap

**Similar Tools:**
- Whisper Flow: https://whisperflow.app
- Super Whisper: https://superwhisper.com
- Talon Voice: https://talonvoice.com

---

## ⚖️ License

OS One is open source. Parakeet models are from NVIDIA (check their license).

---

**Version:** 1.0
**Last Updated:** 2025-12-09
**macOS:** 13.0+ (Ventura)
**Tested On:** Apple Silicon (M1, M2, M3, M4)

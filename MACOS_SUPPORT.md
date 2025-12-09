# macOS Support - OS One

OS One is now a **universal app** that runs natively on both iOS and macOS!

## 🍎 Platform Support

```
iOS:     iPhone 12 Pro Max+ (6GB RAM baseline)
         iPad Pro (all models)

macOS:   macOS 13.0+ (Ventura and later)
         Apple Silicon (M1, M2, M3, M4)
         Intel Macs (with Rosetta)
```

## 🚀 macOS-Specific Features

### 1. **Better Performance**
- Macs have more RAM (8GB, 16GB, 32GB+)
- Can run **Qwen3-4B** with ease (even on 8GB Macs)
- Faster inference on Apple Silicon (M1/M2/M3/M4)
- Sustained performance (better thermal management)

### 2. **Keyboard Shortcuts**
```
⌘R        - Start/Stop Recording
⌘N        - New Conversation
⌘,        - Settings
⌘⇧M       - Toggle Mute
⌘⇧K       - Clear Conversation
⌘Q        - Quit
```

### 3. **Menu Bar**
- **File** → New Conversation (⌘N)
- **Voice** → Start/Stop Recording (⌘R)
- **Voice** → Toggle Mute (⌘⇧M)
- **Voice** → Clear Conversation (⌘⇧K)
- **Settings** → Settings... (⌘,)
- **Help** → OS One Help, Report Issue

### 4. **Window Management**
- Resizable window (min: 600x400, default: 800x600)
- Full screen support (⌃⌘F)
- Multiple windows (future)
- Center window on launch

### 5. **Responsive UI**
- Adapts to window size
- Compact mode (<600px width)
- Standard mode (600-900px)
- Larger fonts for readability

### 6. **Ollama Integration** 🦙
- Third model provider option (macOS exclusive)
- Easy local model management
- No MLX required - uses Ollama runtime
- Compatible with hundreds of models

## 🦙 Ollama Integration (macOS Only)

### Why Ollama?
Ollama provides an easy-to-use local LLM runtime that complements OS One's built-in MLX support:

**Benefits:**
- ✅ Simple installation via Homebrew
- ✅ Huge model library (100+ models)
- ✅ Easy model switching
- ✅ Better for experimentation
- ✅ Lower barrier to entry than MLX

**Use Cases:**
- Testing different models quickly
- Running models not available in MLX format
- Sharing models across applications
- Development and prototyping

### Quick Start

1. **Install Ollama**
   ```bash
   brew install ollama
   ```

2. **Start Ollama Server**
   ```bash
   ollama serve
   ```
   (Runs on localhost:11434)

3. **Pull a Model**
   ```bash
   ollama pull qwen2.5:3b
   # or
   ollama pull llama3.2:3b
   ```

4. **Configure OS One**
   - Open Settings (⌘,)
   - Select "🦙 Ollama" as Model Provider
   - Verify connection status (green = connected)
   - Choose your downloaded model

### Popular Models for OS One

| Model | Size | RAM | Context | Speed | Best For |
|-------|------|-----|---------|-------|----------|
| **qwen2.5:3b** | 2.0GB | 4GB | 32K | Fast | Balanced |
| **llama3.2:3b** | 2.1GB | 4GB | 128K | Fast | Long context |
| **mistral:7b** | 4.1GB | 8GB | 32K | Medium | Quality |
| **gemma2:2b** | 1.6GB | 3GB | 8K | Very Fast | Speed |
| **qwen2.5:7b** | 4.7GB | 8GB | 32K | Medium | Best quality |

### Configuration

**Settings UI (macOS):**
```
Model Provider: 🦙 Ollama

Ollama Endpoint: http://localhost:11434
Status: ● connected

Model: qwen2.5:3b
```

**UserDefaults Keys:**
```swift
modelProvider: "ollama"
ollamaBaseURL: "http://localhost:11434"
ollamaSelectedModel: "qwen2.5:3b"
```

### Model Management

**List downloaded models:**
```bash
ollama list
```

**Remove a model:**
```bash
ollama rm qwen2.5:3b
```

**Update a model:**
```bash
ollama pull qwen2.5:3b  # Re-downloads latest version
```

**Check model info:**
```bash
ollama show qwen2.5:3b
```

### Troubleshooting

**Connection Failed:**
```
Status: ○ not running
Message: "ollama not running - start it with 'ollama serve'"
```

**Solution:**
1. Open Terminal
2. Run `ollama serve`
3. Keep Terminal window open (or run as background service)
4. Refresh OS One settings

**Model Not Found:**
```
Error: model 'qwen2.5:3b' not found
```

**Solution:**
```bash
ollama pull qwen2.5:3b
```

**Slow Performance:**
- Check Activity Monitor for CPU/RAM usage
- Use smaller model (2B-3B instead of 7B)
- Close other applications
- Restart Ollama: `killall ollama && ollama serve`

### MLX vs Ollama Comparison

| Feature | MLX (Built-in) | Ollama |
|---------|----------------|--------|
| **Installation** | Included | Requires Homebrew |
| **Model Format** | MLX-optimized | GGUF/Safetensors |
| **Performance** | Faster (Apple Silicon) | Good |
| **Models Available** | 6 curated | 100+ |
| **Setup Complexity** | Lower | Medium |
| **Model Switching** | App restart | Instant |
| **RAM Usage** | Optimized | Standard |
| **Best For** | Production use | Experimentation |

**Recommendation:**
- Use **MLX** for daily use (better performance)
- Use **Ollama** for testing new models or specific workflows

## 📊 Model Recommendations (macOS)

macOS devices typically have more RAM, so we can be more generous:

| RAM   | Recommended Model | Performance |
|-------|-------------------|-------------|
| 16GB+ | **Qwen 3 4B**    | Excellent, 256K context |
| 8GB   | **Qwen 3 4B**    | Good, still recommended |
| <8GB  | Qwen 2.5 3B      | Adequate |

**Why Macs are better for local AI:**
- More sustained performance (no thermal throttling)
- More RAM available (not shared with OS as much)
- Unified memory architecture (Apple Silicon)
- Faster SSD for model loading

## 🎯 Use Cases

**Mac-Specific Workflows:**
1. **Coding Assistant**
   - Use while coding in Xcode/VS Code
   - Quick voice queries without leaving keyboard
   - 256K context for large codebases

2. **Research & Writing**
   - Long conversations with context retention
   - Multiple document references
   - Academic work with citations

3. **Development Testing**
   - Test local models before deploying to iOS
   - Better debugging tools
   - Faster iteration cycles

## 🛠️ Technical Implementation

### Platform Detection
```swift
Platform.current  // .iOS or .macOS
DeviceInfo.detect()  // Cross-platform device info
```

### Conditional Compilation
```swift
#if os(iOS)
// iOS-specific code
#elseif os(macOS)
// macOS-specific code
#endif
```

### Microphone Permissions
```swift
// macOS requires explicit permission request
MacOSMicrophonePermissions().requestPermission()

// Opens: System Settings > Privacy & Security > Microphone
```

### Keyboard Shortcuts
```swift
// Automatically registered via MenuBarCommands
// Uses NotificationCenter for cross-view communication
```

## 🏗️ Architecture

```
OS One (Universal)
├─ iOS Target
│  ├─ Touch-optimized UI
│  ├─ Mobile-specific layouts
│  └─ Compact models (Qwen 3 4B max)
│
└─ macOS Target
   ├─ Keyboard-optimized UI
   ├─ Window management
   ├─ Menu bar integration
   ├─ Larger models support
   └─ Desktop workflows
```

## 📦 Build & Deploy

### Building for macOS
```bash
# Build for Apple Silicon
xcodebuild -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -destination "platform=macOS,arch=arm64" \
  build

# Build Universal (Apple Silicon + Intel)
xcodebuild -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -destination "platform=macOS" \
  ARCHS="arm64 x86_64" \
  build
```

### Testing on macOS
```bash
# Run tests on macOS
xcodebuild test \
  -project "OS One.xcodeproj" \
  -scheme "OS One" \
  -destination "platform=macOS"
```

### Distribution
- **TestFlight**: Supports macOS distribution
- **Direct Download**: .app bundle
- **Mac App Store**: Full submission process

## 🎨 UI Differences

### iOS
- Touch-first interface
- Vertical layouts (portrait optimized)
- Bottom sheets
- Swipe gestures
- Smaller fonts

### macOS
- Keyboard-first interface
- Horizontal layouts (landscape optimized)
- Popovers & sheets
- Hover states
- Larger fonts

## ⚙️ Settings (macOS)

Additional macOS settings:
- **Launch at Login** (future)
- **Menu Bar Icon** (future)
- **Keyboard Shortcuts** (customizable, future)
- **Window Behavior** (future)

## 🐛 Debugging

### Check Platform
```swift
print("Platform: \(Platform.current.displayName)")
print("RAM: \(DeviceInfo.detect().totalRAMInGB) GB")
print("Processor: \(DeviceInfo.detect().processorName)")
```

### Verify Permissions
```swift
// Check microphone access
let status = AVCaptureDevice.authorizationStatus(for: .audio)
print("Microphone: \(status)")
```

### Model Info
```swift
// See which model is loaded
print("Model: \(localLLM.currentModel?.displayName ?? "none")")
print("Context: \(localLLM.currentModel?.contextWindow ?? 0)K tokens")
```

## 📱 vs 🖥️ Comparison

| Feature | iOS | macOS |
|---------|-----|-------|
| **Portability** | ✅ | ❌ |
| **Performance** | Good | Excellent |
| **RAM Available** | 4-8GB | 8-64GB |
| **Keyboard Shortcuts** | Limited | Full |
| **Menu Bar** | ❌ | ✅ |
| **Window Management** | ❌ | ✅ |
| **Battery Life** | Limited | Plugged In |
| **Model Size** | 4B max | 4B+ future |
| **Context Window** | 256K | 256K |
| **Offline** | ✅ | ✅ |

## 🚧 Future Enhancements

### Planned (macOS-specific)
- [ ] Menu bar app mode
- [ ] Global keyboard shortcut
- [ ] Multi-window support
- [ ] Touch Bar support (MacBook Pro)
- [ ] Siri Shortcuts integration
- [ ] Larger models (7B+) for high-RAM Macs
- [ ] Dock icon customization
- [ ] System tray notifications

### Cross-Platform
- [ ] iCloud sync (conversations, settings)
- [ ] Handoff support (continue on another device)
- [ ] Universal Clipboard
- [ ] AirDrop sharing

## 🎓 Best Practices

### Development
1. **Test on both platforms** before committing
2. **Use platform detection** for conditional features
3. **Respect platform conventions** (menu bar on macOS, etc.)
4. **Optimize for each platform** (don't just port)

### Performance
1. **Take advantage of Mac RAM** (larger contexts)
2. **Use keyboard shortcuts** (faster workflow)
3. **Enable offline mode** (still works without internet)
4. **Monitor memory usage** (Activity Monitor)

### User Experience
1. **Keyboard-first on Mac** (shortcuts for everything)
2. **Touch-first on iOS** (gestures, swipes)
3. **Responsive layouts** (adapt to window size)
4. **Native controls** (platform-appropriate UI)

## 📖 Resources

- [SwiftUI Platform Differences](https://developer.apple.com/documentation/swiftui)
- [macOS App Programming Guide](https://developer.apple.com/macos/)
- [Keyboard Shortcuts](https://developer.apple.com/design/human-interface-guidelines/keyboards)
- [Menu Bar Apps](https://developer.apple.com/design/human-interface-guidelines/menus)

## ⚡ Quick Start (macOS)

1. **Build & Run**
   ```bash
   open "OS One.xcodeproj"
   # ⌘R to build and run
   ```

2. **Grant Permissions**
   - Microphone access required
   - System Settings > Privacy & Security > Microphone

3. **Choose Model Provider**
   - Settings (⌘,) → Model Provider
   - **🔒 Local (MLX)**: Qwen 3 4B (256K context) - Recommended
   - **⚡ Haiku 4.5**: Claude API (requires API key)
   - **🦙 Ollama**: Local models via Ollama (requires `ollama serve`)

4. **Start Using**
   - ⌘R to start recording
   - Talk naturally
   - AI responds via speakers
   - ⌘N for new conversation

**You're ready to go! 🚀**

---

**macOS Support Version:** 1.1 (Ollama Integration)
**Last Updated:** 2025-12-09
**Minimum macOS:** 13.0 (Ventura)
**Optimized For:** Apple Silicon (M1+)

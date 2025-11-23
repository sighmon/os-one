# OS One - Offline Voice AI Setup Guide

Complete guide for setting up OS One as a fully offline, on-device voice AI assistant.

## Table of Contents
- [Requirements](#requirements)
- [Installation](#installation)
- [Model Setup](#model-setup)
- [Configuration](#configuration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Requirements

### Hardware
- **iPhone 15 Pro or newer** (A17 Pro chip recommended)
- **iPad Pro with M-series chip** (M1/M2/M4)
- **Mac with Apple Silicon** (M1 or newer)
- **Minimum 8GB RAM** (16GB recommended for 3B models)
- **Storage:**
  - 1B models: ~1 GB
  - 1.5B models: ~1.2 GB
  - 2B models: ~1.5 GB
  - 3B models: ~2.5 GB

### Software
- **iOS 17.0+** or **macOS 14.0+**
- **Xcode 15.0+**
- **Swift 5.9+**
- **Python 3.9+** (for model conversion, optional)

## Installation

### 1. Install Dependencies

#### Using Xcode
1. Open `OS One.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Add the following packages:
   - MLX Swift: `https://github.com/ml-explore/mlx-swift.git` (version 0.11.0+)
   - Swift Transformers: `https://github.com/huggingface/swift-transformers.git` (version 0.1.5+)

#### Using Swift Package Manager
```bash
# In the project directory
swift package resolve
swift build
```

### 2. Add New Files to Xcode Project

Add these files to your Xcode project:
```
OS One/
├── VoiceActivityDetector.swift
├── LocalLLMManager.swift
├── AudioWaveformView.swift
├── ModelDownloadManager.swift
├── NativeTTSManager.swift
└── (Modified: SpeechRecognizer.swift, HomeView.swift, SettingsView.swift)
```

**In Xcode:**
1. Right-click on "OS One" folder
2. Select "Add Files to OS One..."
3. Select all new Swift files
4. Ensure "Copy items if needed" is checked
5. Click "Add"

### 3. Configure Info.plist

Add required permissions to `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>OS One needs microphone access for voice commands</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>OS One uses speech recognition for voice input</string>

<!-- Optional: For on-device speech recognition -->
<key>NSSpeechRecognitionOnDeviceUsageDescription</key>
<string>OS One uses on-device speech recognition for privacy</string>
```

## Model Setup

### Option 1: Download Pre-Converted Models (Recommended)

*Note: Pre-converted MLX models will be made available soon*

### Option 2: Download and Convert Models Manually

#### Step 1: Install Model Conversion Tools

```bash
# Install MLX and conversion tools
pip install mlx mlx-lm huggingface-hub

# Optional: Install transformers for verification
pip install transformers torch
```

#### Step 2: Download Model from HuggingFace

Create a Python script `download_model.py`:

```python
#!/usr/bin/env python3
"""
Download and convert HuggingFace models to MLX format for OS One
"""

import argparse
from pathlib import Path
from huggingface_hub import snapshot_download

MODELS = {
    "qwen-1.5b": "Qwen/Qwen2.5-1.5B-Instruct",
    "qwen-3b": "Qwen/Qwen2.5-3B-Instruct",
    "gemma-2b": "google/gemma-2-2b-it",
    "llama-1b": "meta-llama/Llama-3.2-1B-Instruct",
    "llama-3b": "meta-llama/Llama-3.2-3B-Instruct",
}

def download_model(model_name: str, output_dir: Path):
    """Download model from HuggingFace"""
    if model_name not in MODELS:
        raise ValueError(f"Unknown model: {model_name}. Choose from {list(MODELS.keys())}")

    repo_id = MODELS[model_name]
    print(f"Downloading {repo_id}...")

    model_path = snapshot_download(
        repo_id=repo_id,
        local_dir=output_dir / repo_id,
        allow_patterns=["*.json", "*.safetensors", "tokenizer.model"],
    )

    print(f"Model downloaded to: {model_path}")
    return model_path

def main():
    parser = argparse.ArgumentParser(description="Download models for OS One")
    parser.add_argument("model", choices=list(MODELS.keys()), help="Model to download")
    parser.add_argument("--output", type=Path, default=Path("./models"), help="Output directory")

    args = parser.parse_args()

    args.output.mkdir(parents=True, exist_ok=True)
    download_model(args.model, args.output)

if __name__ == "__main__":
    main()
```

**Run the download script:**

```bash
# Download Qwen 2.5 1.5B (recommended for iPhone)
python download_model.py qwen-1.5b

# Download Llama 3.2 3B (for iPad Pro/Mac)
python download_model.py llama-3b
```

#### Step 3: Convert to MLX Format

Create conversion script `convert_to_mlx.py`:

```python
#!/usr/bin/env python3
"""
Convert HuggingFace models to MLX format
"""

import argparse
from pathlib import Path
from mlx_lm import convert

def convert_model(model_path: Path, output_path: Path, quantize: str = None):
    """Convert model to MLX format"""
    print(f"Converting {model_path} to MLX format...")

    convert(
        model_path=str(model_path),
        mlx_path=str(output_path),
        quantize=quantize,  # Options: None, "q4", "q8"
        upload_repo=None
    )

    print(f"Conversion complete: {output_path}")

def main():
    parser = argparse.ArgumentParser(description="Convert models to MLX format")
    parser.add_argument("model_path", type=Path, help="Path to HuggingFace model")
    parser.add_argument("--output", type=Path, default=None, help="Output path")
    parser.add_argument("--quantize", choices=["q4", "q8"], default=None,
                       help="Quantization (q4 for mobile, q8 for desktop)")

    args = parser.parse_args()

    output_path = args.output or (args.model_path.parent / f"{args.model_path.name}-mlx")
    convert_model(args.model_path, output_path, args.quantize)

if __name__ == "__main__":
    main()
```

**Convert models:**

```bash
# For iPhone (4-bit quantization for smaller size)
python convert_to_mlx.py models/Qwen/Qwen2.5-1.5B-Instruct --quantize q4

# For iPad Pro/Mac (8-bit for better quality)
python convert_to_mlx.py models/meta-llama/Llama-3.2-3B-Instruct --quantize q8
```

#### Step 4: Copy Models to iOS Device

**Option A: Using Xcode**
1. Add converted model folder to Xcode project
2. Ensure it's added to the app bundle
3. Models will be included in the app

**Option B: Using Files App (Runtime Download)**
1. Upload models to iCloud Drive or use the in-app downloader
2. The app will download models on first run
3. Models stored in app's Documents folder

```swift
// Models will be stored at:
// ~/Documents/LocalModels/[model-name]/
```

### Recommended Models by Device

| Device | Recommended Model | Size | Speed |
|--------|------------------|------|-------|
| iPhone 15 Pro | Qwen 2.5 1.5B (q4) | ~900 MB | Fast |
| iPhone 15 Pro Max | Qwen 2.5 3B (q4) | ~1.8 GB | Medium |
| iPad Pro M2 | Llama 3.2 3B (q8) | ~2.5 GB | Fast |
| MacBook M1+ | Llama 3.2 3B (q8) | ~2.5 GB | Very Fast |

## Configuration

### 1. Enable Offline Mode

Open OS One → Settings:

1. Scroll to **"Offline mode"** section
2. Toggle **"Enable offline mode"** → ON
3. Select your **Local Model** (e.g., "Qwen 2.5 1.5B")

### 2. Configure Voice Activity Detection

1. Toggle **"Voice Activity Detection"** → ON
2. Adjust **VAD Sensitivity**:
   - 30-50%: Low sensitivity (quiet environments)
   - 50-70%: Medium sensitivity (normal use)
   - 70-90%: High sensitivity (noisy environments)

### 3. Configure Speech Recognition

1. Toggle **"On-device speech recognition"** → ON
   - Uses Apple's on-device speech recognition (requires iOS 17+)
   - No internet connection needed
   - Supports multiple languages

### 4. Configure Text-to-Speech

1. Adjust **Speech Rate**: 30-70% (default: 50%)
2. Adjust **Speech Pitch**: 0.8-1.2x (default: 1.0x)
3. Optional: Toggle **"Show waveform"** for visual feedback

### 5. Select Voice

The app automatically selects appropriate voices based on your chosen persona:
- **Samantha** → Samantha (US English, female)
- **KITT** → Fred (US English, male)
- **GLaDOS** → Siri Female (US English, premium)

### 6. Memory Optimization

For optimal performance on mobile devices:

**In Settings:**
- Use smaller models (1B-1.5B) for better battery life
- Enable 4-bit quantization (q4) for iPhone
- Disable "Show waveform" if experiencing lag

**In Xcode Project Settings:**
```swift
// Build Settings → Other Swift Flags
-Xfrontend -enable-actor-data-race-checks

// Optimize for performance
Optimization Level: -O
```

## Testing

### 1. Test Voice Activity Detection

1. Open OS One
2. Speak into the microphone
3. Observe waveform (if enabled)
4. Verify:
   - Speech starts automatically when you speak
   - Speech ends after 1-2 seconds of silence
   - Transcript appears correctly

### 2. Test Local LLM

1. Toggle offline mode ON (Wi-Fi icon with slash)
2. Wait for "model loaded" message
3. Ask a simple question: "Hello, how are you?"
4. Verify:
   - Model responds within 3-5 seconds
   - Response is relevant to your persona
   - No internet connection needed

### 3. Test Native TTS

1. Listen to the AI response
2. Verify:
   - Natural-sounding voice
   - Correct pronunciation
   - Appropriate speed and pitch

### 4. Performance Benchmarks

Expected performance on iPhone 15 Pro:

| Task | Time |
|------|------|
| Model Load (1.5B) | 2-5 seconds |
| First Token | 0.5-1 second |
| Token Generation | 10-20 tokens/sec |
| Full Response (50 tokens) | 3-5 seconds |

## Troubleshooting

### Issue: Model Won't Load

**Symptoms:** "model not loaded" or "model load failed"

**Solutions:**
1. Check model is in correct location:
   ```
   ~/Documents/LocalModels/[ModelName]/
   ```
2. Verify all required files exist:
   - `config.json`
   - `tokenizer.json`
   - `model.safetensors`
   - `generation_config.json`
3. Check available storage (need 2x model size free)
4. Try smaller model (1B instead of 3B)

### Issue: VAD Not Working

**Symptoms:** Speech doesn't start/stop automatically

**Solutions:**
1. Check microphone permissions in Settings → Privacy
2. Adjust VAD sensitivity (try 70%)
3. Ensure "Voice Activity Detection" is enabled
4. Check for background noise (use headphones)

### Issue: Slow Performance

**Symptoms:** Long delays in response generation

**Solutions:**
1. Use smaller model (1B or 1.5B)
2. Use 4-bit quantization (q4)
3. Close other apps
4. Restart device
5. Lower max_tokens to 100-150

### Issue: Out of Memory

**Symptoms:** App crashes or "memory warning"

**Solutions:**
1. Use 4-bit quantized model
2. Reduce conversation history length
3. Clear conversation history regularly
4. Disable waveform visualization
5. Close other apps

### Issue: Speech Recognition Not Working

**Symptoms:** Transcript is empty or incorrect

**Solutions:**
1. Check microphone permissions
2. Speak clearly and at normal volume
3. Reduce background noise
4. Try disabling on-device recognition
5. Check iOS language settings match your speech

### Issue: TTS Sounds Robotic

**Symptoms:** Unnatural-sounding voice

**Solutions:**
1. Download enhanced voices (Settings → Accessibility → Spoken Content)
2. Adjust speech rate (40-60%)
3. Adjust pitch (0.9-1.1x)
4. Select different voice in Settings

## Advanced Configuration

### Custom Model Integration

To add a custom model:

1. **Add model to `LocalModelType` enum** in `LocalLLMManager.swift`:
```swift
enum LocalModelType: String, CaseIterable {
    case myCustomModel = "org/my-model-name"
    // ...
}
```

2. **Add prompt template**:
```swift
var userPromptTemplate: String {
    switch self {
    case .myCustomModel:
        return "[INST] {message} [/INST]"
    // ...
    }
}
```

3. **Update SettingsView** picker to include new model

### Memory Optimization

Edit `LocalLLMManager.swift` for memory optimization:

```swift
struct GenerationConfig {
    var maxTokens: Int = 150  // Reduce from 300
    var temperature: Float = 0.6  // Lower for more focused responses
    var topP: Float = 0.85  // Reduce for faster generation
}
```

### VAD Fine-Tuning

Edit `VoiceActivityDetector.swift` for custom VAD behavior:

```swift
struct Configuration {
    var energyThreshold: Float = 0.015  // Lower for more sensitivity
    var silenceDuration: TimeInterval = 1.0  // Faster cutoff
    var speechStartDuration: TimeInterval = 0.15  // Quicker start
}
```

## Performance Tips

1. **Battery Life:**
   - Use 1B-1.5B models
   - Disable waveform
   - Use on-device speech recognition
   - Enable Low Power Mode

2. **Response Quality:**
   - Use 3B models with 8-bit quantization
   - Increase temperature (0.7-0.8)
   - Keep conversation history

3. **Speed:**
   - Use 4-bit quantization
   - Reduce max_tokens
   - Clear conversation history

4. **Privacy:**
   - Keep offline mode enabled
   - Use on-device speech recognition
   - Disable location services
   - Disable search

## Next Steps

- **Train Custom Models:** Fine-tune models on your own data
- **Add Wake Word:** Implement "Hey Samantha" wake word detection
- **Multi-Language:** Add support for other languages
- **Streaming:** Implement true streaming inference for faster perceived response

## Support

For issues and questions:
- GitHub Issues: [github.com/Mantexas/os-one/issues](https://github.com/Mantexas/os-one/issues)
- Documentation: [github.com/Mantexas/os-one/wiki](https://github.com/Mantexas/os-one/wiki)

## License

OS One is open source under the MIT License.

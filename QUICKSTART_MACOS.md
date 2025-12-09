# QuickStart: macOS Build

**Get OS One running on macOS in 30 minutes**

## Current Status

✅ **Code:** Ready for macOS
✅ **Entitlements:** Configured
✅ **Info.plist:** Updated
⚠️ **Xcode Project:** Needs manual configuration

---

## 🚀 Quick Steps

### 1. Open Xcode (2 mins)

```bash
cd ~/os-one  # or your project path
open "OS One.xcodeproj"
```

### 2. Add New Files (5 mins)

Right-click "OS One" folder → "Add Files to OS One" → Add these 5 files:

- [ ] `ParakeetSTTClient.swift`
- [ ] `GlobalHotkeyManager.swift`
- [ ] `OllamaClient.swift`
- [ ] `PlatformUtility.swift`
- [ ] `MacOSSupport.swift`

**Make sure to:**
- ✅ Check "Copy items if needed"
- ✅ Check "OS One" target

### 3. Enable Mac Catalyst (2 mins)

1. Select "OS One" project (blue icon at top)
2. Select "OS One" target
3. **General** tab → **Supported Destinations**
4. Click **+** → Select **"Mac"**
5. Choose **"Scaled to Match iPad"**

### 4. Fix UIKit Issues (10 mins)

**Option A - Quick (Disable Vision on Mac):**

In `HomeView.swift`, wrap camera icon (around line 217):
```swift
#if !targetEnvironment(macCatalyst)
Image(systemName: "camera")
    .font(.system(size: 25))
    .frame(width: 30)
    .padding(6)
    .opacity(visionEnabled ? 1.0 : 0.4)
    .onTapGesture {
        visionEnabled.toggle()
    }
#endif
```

Also wrap ImagePicker sheet (around line 268):
```swift
#if !targetEnvironment(macCatalyst)
.sheet(isPresented: $showingImagePicker) {
    ImagePicker(image: self.$currentImage, onImagePicked: { selectedImage in
        self.currentImage = selectedImage
        self.continueSendingToOpenAI()
    })
}
#endif
```

**Option B - Full Fix:**

See `XCODE_MACOS_SETUP.md` Part 5 for complete ImagePicker implementation.

### 5. Build & Run (5 mins)

1. Select destination: **"My Mac (Mac Catalyst)"**
2. Product → Clean Build Folder (⌘⇧K)
3. Product → Build (⌘B)
4. Product → Run (⌘R)

**Grant permissions when prompted:**
- ✅ Microphone access
- ✅ Accessibility (for global hotkeys)

### 6. Test Features (5 mins)

- [ ] App launches
- [ ] Settings open (⌘,)
- [ ] Ollama settings visible (macOS only)
- [ ] Parakeet STT settings visible (macOS only)
- [ ] Global dictation settings visible (macOS only)
- [ ] Voice input works

---

## 📚 Documentation

**Detailed guides:**
- `XCODE_MACOS_SETUP.md` - Complete step-by-step (45 mins)
- `BUILD_READINESS.md` - Technical assessment
- `MACOS_SUPPORT.md` - macOS features overview
- `PARAKEET_GUIDE.md` - Parakeet & Global Dictation

**Build script:**
```bash
./build-macos.sh  # Automated build (after Xcode config)
```

---

## ⚡ One-Liner Setup

For experienced developers:

```
1. Open Xcode
2. Add 5 new .swift files to project
3. Enable Mac Catalyst in target
4. Wrap camera/ImagePicker with #if !targetEnvironment(macCatalyst)
5. Build for "My Mac (Mac Catalyst)"
```

---

## 🐛 Common Issues

### "No such module 'UIKit'"
Add to top of file:
```swift
#if canImport(UIKit)
import UIKit
#endif
```

### "My Mac" destination not showing
- General tab → Supported Destinations → Add "Mac"
- Restart Xcode if needed

### Build succeeds but crashes
- Check console for errors (⌘⇧Y)
- Verify entitlements linked in Signing & Capabilities
- Delete app from Applications folder and rebuild

### Global hotkeys don't work
- System Settings → Privacy & Security → Accessibility
- Enable "OS One"
- Restart app

---

## ✅ Success Criteria

You're ready when:
- ✅ App builds without errors
- ✅ App launches on Mac
- ✅ Settings show macOS-only features
- ✅ Voice input works
- ✅ No crashes on basic usage

---

## 🎯 Next Steps After Success

1. **Test Ollama** (if installed)
   ```bash
   brew install ollama
   ollama serve
   ollama pull qwen2.5:3b
   ```

2. **Test Parakeet STT**
   - Start inference server on localhost:8000
   - Enable in Settings

3. **Test Global Dictation**
   - Enable in Settings
   - Grant accessibility permissions
   - Try in any app (Chrome, Notes, Slack)

4. **Package for Distribution**
   - See `BUILD_READINESS.md` for DMG creation
   - Code sign for distribution
   - Submit to Mac App Store (optional)

---

**Need help?** Check `XCODE_MACOS_SETUP.md` for detailed instructions.

**Ready to ship?** See `BUILD_READINESS.md` for packaging guide.

🚀 **Happy building!**

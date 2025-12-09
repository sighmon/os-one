# Xcode macOS Setup Guide - OS One

**Step-by-step instructions to enable macOS builds using Mac Catalyst**

Time required: **30-45 minutes**

---

## Prerequisites

- ✅ macOS 13.0+ (Ventura or later)
- ✅ Xcode 15.0+ installed
- ✅ Apple Developer account (free tier works for development)

---

## Part 1: Add New Files to Xcode Project (10 mins)

### Files to Add:

The following files exist in the filesystem but aren't in the Xcode project:

```
OS One/ParakeetSTTClient.swift
OS One/GlobalHotkeyManager.swift
OS One/OllamaClient.swift
OS One/PlatformUtility.swift
OS One/MacOSSupport.swift
```

### Steps:

1. **Open the project**
   ```bash
   cd ~/os-one  # or wherever your project is
   open "OS One.xcodeproj"
   ```

2. **Add ParakeetSTTClient.swift**
   - In Xcode, right-click on the "OS One" folder (blue folder icon)
   - Select **Add Files to "OS One"**
   - Navigate to `OS One/ParakeetSTTClient.swift`
   - **Check** "Copy items if needed"
   - **Check** "OS One" under "Add to targets"
   - Click **Add**

3. **Repeat for each file:**
   - GlobalHotkeyManager.swift
   - OllamaClient.swift
   - PlatformUtility.swift
   - MacOSSupport.swift

4. **Verify files are added:**
   - Look in Xcode's file navigator (left sidebar)
   - All 5 files should appear with normal text (not grayed out)
   - Click each file - it should show Swift code

---

## Part 2: Enable Mac Catalyst (5 mins)

### Steps:

1. **Select the project**
   - Click "OS One" at the top of the file navigator (blue project icon)

2. **Select the target**
   - Under "TARGETS", click "OS One"

3. **Go to General tab**
   - Should be selected by default

4. **Enable Mac**
   - Scroll to "Supported Destinations"
   - Click the **+ button**
   - Select **"Mac"** from the dropdown
   - OR: Check the **"Mac"** checkbox if visible

5. **Choose Mac interface**
   - Select "Optimize Interface for Mac"
   - Choose **"Scaled to Match iPad"** (easier) or **"Mac Idiom"** (native look)

   **Recommendation:** Start with "Scaled to Match iPad" for faster setup

6. **Verify**
   - At the top of Xcode, click the destination dropdown (left of play button)
   - You should see "My Mac (Mac Catalyst)" option

---

## Part 3: Configure Entitlements (2 mins)

### Steps:

1. **Verify entitlements file**
   - Click on `OS One.entitlements` in the file navigator
   - Should contain these keys:
     - ✅ `com.apple.security.device.audio-input` = true
     - ✅ `com.apple.security.network.client` = true
     - ✅ `com.apple.security.files.user-selected.read-only` = true

2. **Link entitlements to target**
   - Select "OS One" project → "OS One" target
   - Go to **"Signing & Capabilities"** tab
   - Under "Debug", find "Entitlements File"
   - Should say: `OS One/OS One.entitlements`
   - If not, click and select the file

3. **Repeat for Release**
   - Switch to "Release" tab (dropdown at top)
   - Verify entitlements file is linked

---

## Part 4: Verify Info.plist (1 min)

### Steps:

1. **Open Info.plist**
   - Click `Info.plist` in file navigator

2. **Verify keys exist:**
   - ✅ `NSMicrophoneUsageDescription`
   - ✅ `NSAccessibilityUsageDescription`
   - ✅ `NSSpeechRecognitionUsageDescription`

3. **If missing, add them:**
   - Right-click in Info.plist editor
   - Select "Add Row"
   - Paste key name
   - Add description string

---

## Part 5: Fix UIKit Compatibility Issues (15 mins)

Some files use iOS-only UIKit APIs. We need to make them conditional.

### Option A: Quick Fix (Recommended)

Wrap problematic UIKit code with Mac Catalyst checks:

**In HomeView.swift** (line ~8):

```swift
// BEFORE:
import UIKit

// AFTER:
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
```

**In ImagePicker section** (around line 872):

```swift
// BEFORE:
struct ImagePicker: UIViewControllerRepresentable {
    // ... code ...
}

// AFTER:
#if !targetEnvironment(macCatalyst)
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // Not needed for basic functionality
    }

    func makeCoordinator() -> ImagePickerCoordinator {
        ImagePickerCoordinator(self)
    }
}

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: ImagePicker

    init(_ parent: ImagePicker) {
        self.parent = parent
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let uiImage = info[.originalImage] as? UIImage {
            parent.onImagePicked(uiImage)
        }
        parent.presentationMode.wrappedValue.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        parent.presentationMode.wrappedValue.dismiss()
    }
}
#else
// macOS placeholder - image picking not supported yet
struct ImagePicker: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    var body: some View {
        Text("Image picking not supported on macOS yet")
            .onAppear {
                presentationMode.wrappedValue.dismiss()
            }
    }
}
#endif
```

**In HomeView.swift - Update references:**

Find where ImagePicker is used (around line 268-272):

```swift
// Should be inside:
#if !targetEnvironment(macCatalyst)
.sheet(isPresented: $showingImagePicker) {
    ImagePicker(image: self.$currentImage, onImagePicked: { selectedImage in
        self.currentImage = selectedImage
        self.continueSendingToOpenAI()
    })
}
#endif
```

### Option B: Disable Vision on macOS (Simpler)

If image picking isn't critical for macOS:

**In HomeView.swift** (around line 217):

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

---

## Part 6: Build for macOS (2 mins)

### Steps:

1. **Select Mac destination**
   - At top of Xcode, click destination dropdown
   - Select **"My Mac (Mac Catalyst)"**

2. **Clean build folder** (recommended)
   - Menu: **Product** → **Clean Build Folder** (⌘⇧K)

3. **Build**
   - Menu: **Product** → **Build** (⌘B)
   - Wait for build to complete
   - Check for errors in the Issue Navigator (⚠️ icon in left sidebar)

4. **Fix any errors**
   - Common errors:
     - Missing imports: Add `#if canImport(UIKit)` guards
     - Undefined symbols: Check file is added to target
     - Entitlement errors: Verify entitlements file linked

---

## Part 7: Run & Test (5 mins)

### Steps:

1. **Run the app**
   - Click **Play** button (▶) or press ⌘R
   - App should launch on your Mac!

2. **Grant permissions**
   - When prompted, click **Allow** for microphone access
   - System Settings may open for accessibility (for global hotkeys)

3. **Test basic functionality:**
   - [ ] App launches without crashes
   - [ ] Can open Settings (⌘, or tap gear icon)
   - [ ] Model provider picker shows all three options
   - [ ] Ollama settings visible (macOS only)
   - [ ] Parakeet STT settings visible (macOS only)
   - [ ] Global dictation settings visible (macOS only)

4. **Test voice input:**
   - [ ] Click microphone icon or press ⌘R
   - [ ] Speak something
   - [ ] Check transcription appears
   - [ ] AI responds (if model configured)

---

## Part 8: Advanced - Native macOS App (Optional)

For a better macOS experience, create a native macOS target:

### Steps:

1. **Create macOS target**
   - Menu: **File** → **New** → **Target**
   - Select **macOS** → **App**
   - Name: "OS One macOS"
   - Language: Swift
   - Interface: SwiftUI
   - Click **Finish**

2. **Share code between targets**
   - Select each `.swift` file in navigator
   - In **File Inspector** (right sidebar)
   - Under "Target Membership"
   - Check both "OS One" AND "OS One macOS"

3. **Create macOS-specific app entry**
   - Create new file: `OS_One_macOSApp.swift`
   - Add to "OS One macOS" target only

   ```swift
   import SwiftUI

   @main
   struct OS_One_macOSApp: App {
       var body: some Scene {
           WindowGroup {
               HomeView()
           }
           .windowStyle(.hiddenTitleBar)
           .windowToolbarStyle(.unified)
           #if os(macOS)
           .commands {
               MenuBarCommands()
           }
           #endif
       }
   }
   ```

4. **Configure build settings**
   - Select "OS One macOS" target
   - General → Deployment Info
   - Set minimum to **macOS 13.0**
   - Supported architectures: **arm64, x86_64** (Universal)

---

## Troubleshooting

### Build Error: "No such module 'UIKit'"

**Solution:** Add import guards:
```swift
#if canImport(UIKit)
import UIKit
#endif
```

### Build Error: "Cannot find type 'UIImage'"

**Solution:** Use conditional compilation:
```swift
#if os(iOS)
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformImage = NSImage
#endif
```

### App crashes on launch

**Solution:** Check console for errors:
- Xcode → View → Debug Area → Show Debug Area (⌘⇧Y)
- Look for error messages
- Common issue: Missing entitlements

### Microphone permission not requested

**Solution:**
1. Check Info.plist has `NSMicrophoneUsageDescription`
2. Verify entitlements file has `com.apple.security.device.audio-input`
3. Delete app and reinstall

### Global hotkeys don't work

**Solution:**
1. Check `NSAccessibilityUsageDescription` in Info.plist
2. Go to System Settings → Privacy & Security → Accessibility
3. Enable "OS One"
4. Restart app

### "My Mac (Mac Catalyst)" not showing

**Solution:**
1. Select project in navigator
2. Select "OS One" target
3. General tab → Supported Destinations
4. Click + → Add "Mac"
5. Restart Xcode if needed

---

## Verification Checklist

Before considering the setup complete:

### Files
- [x] All new .swift files added to Xcode project
- [x] No red file names in navigator
- [x] Can click each file and see code

### Configuration
- [x] Mac Catalyst enabled in target
- [x] "My Mac (Mac Catalyst)" visible in destination menu
- [x] Entitlements file linked in Signing & Capabilities
- [x] Info.plist has all usage description keys

### Build
- [x] Project builds without errors (⌘B succeeds)
- [x] No warnings about missing files
- [x] Build log shows "Build Succeeded"

### Runtime
- [x] App launches on Mac
- [x] No immediate crashes
- [x] Settings accessible
- [x] macOS-only features visible (Ollama, Parakeet, Global Dictation)
- [x] Microphone permission requested
- [x] Can record voice input

---

## Next Steps

Once macOS build is working:

1. **Test Ollama integration** (if Ollama installed)
   ```bash
   brew install ollama
   ollama serve  # In separate terminal
   ollama pull qwen2.5:3b
   ```

2. **Test Parakeet STT** (if you have inference server)
   - Start server on localhost:8000
   - Enable in Settings
   - Test voice input

3. **Test Global Dictation**
   - Enable in Settings
   - Grant accessibility permissions
   - Open any app (Notes, Chrome, etc.)
   - Press Fn key and speak

4. **Create build archive**
   - See BUILD_READINESS.md for packaging instructions

---

## Support

**Issues?**
- Check BUILD_READINESS.md for detailed troubleshooting
- Review MACOS_SUPPORT.md for feature documentation
- Report bugs: https://github.com/sighmon/os-one/issues

**Success?**
- Test all macOS features
- Create DMG for distribution
- Submit to Mac App Store (optional)

---

**Good luck! You're almost there! 🚀**

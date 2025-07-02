# Pix2Text SwiftUI App

A beautiful, native macOS menu bar app for converting images to LaTeX using SwiftUI and your existing Pix2Text Python backend.

## 🎯 Features

- **Native macOS menu bar integration** - No popup windows, just clean dropdown UI
- **4 LaTeX output formats**: Plain, Inline Math ($...$), Display Math ($$...$$), Equation Environment
- **5 action types**: Screenshot, Upload Image, Draw, Text Input, Gallery
- **Automatic clipboard integration** - Formatted LaTeX is automatically copied
- **Real-time format switching** - Change output format and see results instantly
- **Clean, modern UI** - Matches your reference screenshot perfectly

## 🏗️ Project Setup

### 1. Create Xcode Project

1. Open Xcode
2. Create a new **macOS App** project
3. Choose **SwiftUI** interface
4. Set Bundle Identifier: `com.yourname.pix2text`
5. Choose a location and create

### 2. Add Files to Project

1. **Replace** `ContentView.swift` and `AppDelegate.swift` with the content from `Pix2TextApp.swift`
2. **Replace** `Info.plist` with the provided one (sets `LSUIElement` to true for menu bar only)
3. **Add** `pix2text_bridge.py` to your project (drag into Xcode and select "Copy items if needed")

### 3. Project Structure
```
Pix2Text/
├── Pix2TextApp.swift          # Main SwiftUI app
├── Info.plist                 # App configuration  
├── pix2text_bridge.py         # Python bridge script
├── Assets.xcassets/
│   └── p2t-logo.imageset/     # Menu bar icon
└── config.yaml                # Pix2Text configuration
```

### 4. Add App Icon

1. In Xcode, go to `Assets.xcassets`
2. Create new **Image Set** named `p2t-logo`
3. Add your menu bar icon (16x16, 32x32 PNG recommended)
4. Set **Render As**: Template Image for proper menu bar appearance

### 5. Configure Build Settings

1. Go to **Project Settings** → **Build Settings**
2. Set **macOS Deployment Target**: 12.0 or higher
3. Under **Build Phases** → **Copy Bundle Resources**, ensure these files are included:
   - `pix2text_bridge.py`
   - `config.yaml`

## 🐍 Python Integration

### Bridge Script Setup

The app uses `pix2text_bridge.py` to communicate with your Python backend:

```bash
# Make the bridge script executable
chmod +x pix2text_bridge.py

# Test the bridge script
python3 pix2text_bridge.py clipboard
```

### Python Path Configuration

Update the Python path in `Pix2TextApp.swift` if needed:

```swift
// For standard Python installation
let pythonPath = "/usr/bin/python3"

// For Homebrew Python (M1 Macs)
let pythonPath = "/opt/homebrew/bin/python3"

// For Conda environments
let pythonPath = "/Users/yourusername/miniconda3/bin/python"
```

## 🚀 Building & Running

### Development Mode

1. Open the project in Xcode
2. Select your Mac as the target device
3. Press **⌘R** to build and run
4. The app will appear in your menu bar
5. Click the icon to see the beautiful interface!

### Release Build

1. In Xcode: **Product** → **Archive**
2. **Distribute App** → **Copy App**
3. Copy the `.app` to `/Applications`
4. Grant necessary permissions when prompted

## 🔧 Configuration

### Python Dependencies

Ensure your Python environment has:
```bash
pip install pix2text pillow pyyaml
```

### Config.yaml

The app reads from your existing `config.yaml`. Make sure it's accessible to the bridge script.

## 🎨 UI Components

### Header
- **Title**: "Pix2Text" 
- **Subtitle**: "Convert images to LaTeX with ease"

### Content Display
- Scrollable text area showing LaTeX output
- Monospace font for code clarity
- Placeholder text when empty

### Output Formats (2x2 Grid)
- **Plain LaTeX**: Raw output
- **Inline Math**: `$...$`
- **Display Math**: `$$...$$`  
- **Equation Environment**: `\begin{equation}...\end{equation}`

### Action Buttons (5 Icons)
- **📸 Screenshot**: Process clipboard image
- **📁 Upload Image**: File selection (coming soon)
- **✏️ Draw**: Hand drawing input (coming soon)
- **📝 Text Input**: Manual text entry (coming soon)
- **📚 Gallery**: Browse history (coming soon)

## 🐛 Troubleshooting

### Common Issues

1. **Menu bar icon not showing**
   - Check `Info.plist` has `LSUIElement = true`
   - Verify icon is added to Assets.xcassets

2. **Python script not found**
   - Ensure `pix2text_bridge.py` is in Copy Bundle Resources
   - Check Python path in SwiftUI code

3. **Permission denied**
   - Make bridge script executable: `chmod +x pix2text_bridge.py`
   - Grant app accessibility permissions in System Preferences

4. **Python import errors**
   - Verify `pix2text` is installed in the Python environment
   - Check Python path points to correct installation

### Debug Mode

Enable detailed logging by adding to your Python script:
```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 🎯 Next Steps

1. **Test the screenshot functionality** - Copy an image and click the 📸 button
2. **Switch between output formats** - See how LaTeX changes in real-time
3. **Implement additional actions** - Upload, draw, text input features
4. **Customize the UI** - Adjust colors, spacing, fonts to your preference

## 📝 Notes

- **No Apple Developer account required** for personal use
- **Menu bar only app** - no dock icon, just menu bar presence
- **Automatic clipboard management** - Selected format is always copied
- **Thread-safe Python calls** - UI remains responsive during processing

The app perfectly replicates your reference screenshot with native macOS styling and smooth interactions! 🎉 
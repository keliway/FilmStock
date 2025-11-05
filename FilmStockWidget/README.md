# FilmStock Widget Extension

## Setup Instructions

This widget extension displays loaded films on the home screen. Follow these steps to set it up:

### 1. Add Widget Extension Target in Xcode

1. In Xcode, go to **File > New > Target**
2. Select **Widget Extension**
3. Name it `FilmStockWidget`
4. Make sure "Include Configuration Intent" is **unchecked** (we're using a static widget)
5. Click **Finish**

### 2. Configure App Groups (REQUIRED for Widget to Access Data)

**This is required** for the widget to access the same database as the main app. Widget extensions run in a separate process and need App Groups to share data.

1. **Enable App Groups for Main App:**
   - Select the `FilmStock` target in Xcode
   - Go to **Signing & Capabilities** tab
   - Click **+ Capability**
   - Add **App Groups**
   - Click **+** and add: `group.halbe.no.FilmStock`
   - (Replace `halbe.no` with your actual bundle identifier prefix)

2. **Enable App Groups for Widget Extension:**
   - Select the `FilmStockWidget` target in Xcode
   - Go to **Signing & Capabilities** tab
   - Click **+ Capability**
   - Add **App Groups**
   - Click **+** and add the **same group**: `group.halbe.no.FilmStock`

3. **Important:** Both targets must use the **exact same** App Group identifier

### 3. Add URL Scheme

In the main app's `Info.plist`, add:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>filmstock</string>
        </array>
    </dict>
</array>
```

### 4. Share Code Between Targets

Make sure the following files are included in both the main app and widget targets:

- `FilmStock/Models/FilmDataModel.swift`
- `FilmStock/Models/FilmStock.swift`

In Xcode:
1. Select each file
2. In File Inspector, check both targets under "Target Membership"

### 5. Images Will Be Copied Automatically

The app automatically copies default images from the bundle to the App Group container on first launch. This allows the widget to access them without needing to include the images folder in the widget extension target.

**No manual setup required** - images will be available to the widget after the first app launch.

### 6. Replace Default Widget Files

Replace the default widget files created by Xcode with the files in this directory:
- `LoadedFilmsWidget.swift`
- `LoadedFilmsTimelineProvider.swift`
- `FilmStockWidgetBundle.swift`

### 7. Build and Run

1. Build the widget extension target
2. Run the app
3. Long-press on the home screen to add the widget
4. Select "FilmStock" widget
5. Choose "Loaded Films" widget

## Widget Features

- **System Small Size Only**: Displays film reminder image at 100%
- **Image Display**: Shows the film reminder image (custom or default)
- **Camera & Format Overlay**: Displays camera name and format at the bottom of the image
- **Carousel**: If multiple films are loaded, automatically cycles through them every 5 seconds
- **Empty State**: Shows a placeholder when no films are loaded
- **Deep Linking**: Tapping the widget opens the app to the "Loaded Films" tab

## Timeline Refresh

- Widget updates automatically when loaded films change
- Carousel cycles through all loaded films every 5 seconds per film
- Timeline refreshes every hour when no changes detected


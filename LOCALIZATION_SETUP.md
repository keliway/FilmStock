# Localization Setup for FilmStock

## ✅ What's Already Done

I've created the localization infrastructure:

1. **Created Localizable.strings files:**
   - `FilmStock/en.lproj/Localizable.strings` (English)
   - `FilmStock/de.lproj/Localizable.strings` (German)

2. **Updated Key Views to use localization:**
   - MainTabView (tab labels)
   - BrowseView (title, empty state, search placeholder)
   - LoadedFilmsView (title, empty state, help)
   - CollectionView (title, empty state, help)
   - And more...

## 🔧 Xcode Configuration Steps

### 1. Add the Localization Files to Xcode

1. In Xcode, **right-click** on the `FilmStock` folder in the Project Navigator
2. Select **Add Files to "FilmStock"...**
3. Navigate to and select both:
   - `FilmStock/en.lproj` folder
   - `FilmStock/de.lproj` folder
4. Make sure **"Copy items if needed"** is **unchecked** (they're already in place)
5. Make sure **"Create groups"** is selected
6. Make sure the **FilmStock target** is checked
7. Click **Add**

### 2. Enable German Localization in Project Settings

1. Select the **FilmStock** project in the Project Navigator (top item)
2. Select the **FilmStock** target
3. Go to the **Info** tab
4. Under **Localizations**, you should see "English"
5. Click the **+** button below the localizations list
6. Select **German (de)** from the dropdown
7. Xcode will show a dialog asking which files to localize
8. Check the `Localizable.strings` file
9. Click **Finish**

### 3. Verify the Setup

1. In the Project Navigator, expand the `en.lproj` and `de.lproj` folders
2. You should see `Localizable.strings` in each
3. Click on `Localizable.strings` in the left sidebar
4. In the **File Inspector** (right sidebar), you should see:
   - **Localization** section showing both "English" and "German (de)"

### 4. Test the Localization

#### In Simulator:
1. Run the app
2. Go to iOS **Settings → General → Language & Region**
3. Change **iPhone Language** to **Deutsch** (German)
4. Go back to FilmStock
5. The app should now display in German!

#### In Xcode (faster for testing):
1. Click on the scheme selector (next to the play button)
2. Select **Edit Scheme...**
3. Go to **Run → Options**
4. Under **App Language**, select **German (de)**
5. Run the app - it will launch in German

## 📝 Adding More Strings

When you add new UI elements with text:

```swift
// Simple text (auto-localizable)
Text("key.name")

// With comment for translators
Text("key.name", comment: "Description for translators")

// For non-Text strings
let message = String(localized: "key.name")
```

Then add the key to both `Localizable.strings` files:

```
// en.lproj/Localizable.strings
"key.name" = "English text";

// de.lproj/Localizable.strings
"key.name" = "German text";
```

## 🌍 Adding More Languages

1. Follow step 2 above but select a different language
2. Duplicate the German `Localizable.strings` file
3. Translate all the strings to the new language
4. Add the new `.lproj` folder to Xcode (step 1)

## 🔍 Finding Untranslated Strings

Run the app in Xcode with these settings:

1. **Edit Scheme → Run → Options**
2. **App Language**: Choose **"Double-Length Pseudolanguage"**
3. This will show `[English Text]` for all localized strings
4. Any text not wrapped in brackets needs localization!

## ✨ What Gets Auto-Localized

These work automatically once the `.strings` files are set up:
- ✅ `Text("key")` views
- ✅ `.navigationTitle("key")`
- ✅ Button labels
- ✅ Alert titles and messages
- ✅ TextField prompts

These need `String(localized:)`:
- ❌ String variables
- ❌ Computed properties returning String
- ❌ String concatenation

## 📊 Coverage Status

### ✅ Fully Localized:
- Tab bar labels
- Navigation titles
- Empty states
- Help messages
- Common actions (Add, Edit, Delete, etc.)

### ⚠️ Partially Localized:
- Settings view (some strings)
- About view (some strings)
- Alert messages (some)

### ❌ Not Yet Localized:
- Film detail views
- Add/Edit film forms
- Filter views
- Load film dialogs
- Toast messages
- Error messages

You can continue adding localization keys as needed!

## 🎯 Next Steps

1. Complete the Xcode setup above
2. Test the app in German
3. Add more localization keys for remaining views
4. Consider hiring a native German speaker to review translations

---

**Note:** The current German translations are machine-generated. For a production app, have them reviewed by a native German speaker who understands photography terminology!


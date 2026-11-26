# Analog FilmStock — Full End-to-End Test Script & QA Checklist

This document covers **100% of Analog FilmStock's features** end-to-end, combining:
1. **Automated Test Execution** (`FilmStockTests` Swift Testing unit/integration suite + `FilmStockUITests` XCUITest UI suite + `run_e2e_tests.sh`).
2. **Step-by-Step Manual QA Test Script** for verifying every screen, edge case, physical-device hardware flow (Camera, Photo Library, DX/UPC Barcode Scanner), StoreKit In-App Purchase, Home Screen Widget, and App Group / Deep Link integration.

---

## Quick Start — Running Automated Tests

| Goal | Command / Action |
| :--- | :--- |
| **Run everything in Xcode** | Select scheme **`FilmStock`** -> press **`Cmd + U`** |
| **Run full suite from Terminal** | `bash run_e2e_tests.sh` |
| **Run Unit & Integration tests only** | `bash run_e2e_tests.sh --unit` |
| **Run End-to-End UI tests only** | `bash run_e2e_tests.sh --ui` |

> **Data Safety Guarantee:** All automated UI tests launch the app with `-UITesting`, which switches SwiftData to an **in-memory store**, isolates custom reminder card photos into a temporary directory, and resets settings in-process so real user data on Simulator/device is never modified.

---

## Automated Coverage Matrix

| Area | Unit / Integration (`FilmStockTests`) | UI E2E (`FilmStockUITests`) |
| :--- | :---: | :---: |
| Models, `Codable`, Storage Mutual Exclusion (`Frozen` vs `Fridge`), Bulk Roll (`-2`) | ✅ | ✅ |
| Expiry Date Parsing (`YYYY`, `MMYYYY`, `MM/YY`, `YYYY-MM-DD`, leap years) & Validation | ✅ | ✅ |
| First-Launch Welcome Onboarding (4 pages, `Skip`, `Get Started`) + Sequential Tooltips | ✅ | ✅ |
| Post-Update `What's New` Sheet (Automatic & Settings manual trigger) | — | ✅ |
| Built-in & Custom Manufacturers (Pinned order, Add, Search, Duplicate/In-Use Delete Guard) | ✅ | ✅ |
| Add Film, Auto-Metadata Detection (`manufacturers.json`), Roll Batch Splitting & Sheet Merging | ✅ | ✅ |
| Film Detail, Edit Film Metadata, Collision Merge, Roll Group Edit, Inline Sheet Controls | ✅ | ✅ |
| Legacy Multi-Quantity Roll Migration & Database Self-Healing Integrity Repair | ✅ | — |
| Search, Multi-Facet Filtering, Filter Badge, Reset, Sorting, Group By & Cards/Table View Toggle | — | ✅ |
| Manage Cameras (Add, Edit, Format Matching, Auto-Selection, In-Use Delete Protection) | ✅ | ✅ |
| Load Film (Roll Picker, Sheet Quantity, Custom `Shoot at ISO`, Cannot-Delete-Loaded Guard) | ✅ | ✅ |
| Loaded Films (Roll Details, Live Comment Sync, Change Date, Partial Sheet Unload, Finish, Remove) | ✅ | ✅ |
| Finished Rolls (Status `To develop` -> `In development` -> `Developed`, Edit Date, Filter, `Re-load`) | ✅ | ✅ |
| My Collection (Custom Reminder Cards Grid, Paging Viewer, Multi-Select Delete, Unreferenced Cleanup) | ✅ | ✅ |
| Settings (Fridge Mode, Expiry Chip, Table Default, Custom Formats, Statistics, Appearance, Legal) | ✅ | ✅ |
| Export & Import Round-Trip (JSON & RFC-4180 CSV across Inventory, Loaded, Finished, Cameras) | ✅ | ✅ (UI) |

---

## Manual End-to-End QA Test Script (Every Feature)

Use the checkboxes below during release sign-off on a physical iPhone (recommended for Camera, Barcode Scanner, Widget, and StoreKit) and/or Simulator.

### Suite 1 — First Launch, Onboarding & What's New
- [ ] **1.1 Clean Install Welcome Screen**
  - **Precondition:** Fresh install of `Analog FilmStock`.
  - **Steps:** Launch app -> swipe through pages 1–3 (`Welcome to FilmStock!`, `Track Your Collection`, `Manage Loaded Films`) or tap **`Skip`** -> verify jump to page 4 (`Custom Film Reminder Cards`) -> tap **`Get Started`**.
  - **Expected:** `WelcomeView` dismisses; `My Films` tab appears with empty state (`No Films Yet`).
- [ ] **1.2 Sequential Onboarding Tooltips**
  - **Steps:** Wait 0.5s after dismissing `WelcomeView` -> verify **`Add Your First Film`** tooltip highlights `+` -> tap **`Got it`** -> wait 0.3s -> verify **`Filter Your Films`** tooltip highlights filter button -> tap **`Got it`**.
  - **Expected:** Both tooltips dismiss cleanly and do not reappear on subsequent launches.
- [ ] **1.3 Post-Update What's New Sheet**
  - **Steps:** Open **`Settings`** (gear icon) -> scroll down and tap **`What's New`** -> verify feature list (`Comments on Loaded Films`) -> tap **`Continue`**.
  - **Expected:** Sheet presents with `.large` detent and dismisses cleanly.

---

### Suite 2 — Adding Films, Manufacturers, Formats & Barcode Scanning
- [ ] **2.1 Save Button Validation**
  - **Steps:** Tap **`+`** on `My Films` -> verify **`Save`** is disabled -> select manufacturer **`Kodak`**, leave `Name` empty -> verify **`Save`** remains disabled -> enter `"   "` (spaces) after adding a roll and tap **`Save`**.
  - **Expected:** Inline validation error `"Film name cannot be empty"` appears; film is not saved.
- [ ] **2.2 Built-In Film Auto-Metadata & Default Reminder Card**
  - **Steps:** In `Add Film`, select Manufacturer **`Ilford`** -> type Name **`HP5 Plus`**.
  - **Expected:** `Type` auto-sets to **`B&W`**, `Speed` wheel auto-scrolls to **`ISO 400`**, and the default `Ilford HP5 Plus` reminder card thumbnail appears automatically.
- [ ] **2.3 Custom Manufacturer Lifecycle & Protection**
  - **Steps:** Tap **`Manufacturer`** -> tap **`+`** -> enter `"Kodak"` -> verify duplicate warning (`"This manufacturer already exists."` and `Add` disabled) -> enter `"Silbersalz35"` -> tap **`Add`**. Save a film with `"Silbersalz35"`, then open `Manufacturer` picker again and swipe left on `"Silbersalz35"` -> tap **`Delete`**.
  - **Expected:** Alert **`Cannot Delete Manufacturer`** prevents deleting a manufacturer in use. After deleting all `"Silbersalz35"` films, swiping left -> **`Delete`** removes `"Silbersalz35"`. Built-in manufacturers have no delete action.
- [ ] **2.4 Roll Batch Validation, Exposures & Bulk Rolls**
  - **Steps:** In `Add Film`, tap **`Add Rolls`** -> test Expiry Date inputs:
    1. Type `"123"` -> **`Save`** -> error `"Date must be YYYY or MM/YYYY"`.
    2. Type `"132028"` -> **`Save`** -> error `"Month must be between 01 and 12"`.
    3. Type `"1940"` -> **`Save`** -> error `"Year must be between 1950 and 2100"`.
    4. Type `"082028"` -> auto-formats to **`08/2028`**.
  - **Steps (Exposures):** Keep Format **`35mm`** -> test `Exposures` picker (`Unspecified`, `12`, `24`, `36`, `100ft bulk`, and `Custom` -> enter `18`). Switch Format to **`120`** -> verify `Exposures` section hides.
  - **Expected:** All validation rules trigger accurately; saving adds the batch row (e.g., `2 rolls 35mm (08/2028) · 18 exp`).
- [ ] **2.5 Large Format Sheets (`4x5`, `5x7`, `8x10`)**
  - **Steps:** Add a film (`Kodak Portra 160`) -> **`Add Rolls`** -> select Format **`4x5`** -> verify stepper switches to **`Sheets: %d`** -> set to `10`, toggle **`Film is frozen`**, enter comment `"Studio portraits"`, save batch and save film.
  - **Expected:** Film appears in `My Films` showing `4x5: 10` and `FROZEN` chip; top roll counter only counts rolls (not sheets).
- [ ] **2.6 DX Canister & Box Barcode Scanner *(Physical Device)***
  - **Steps (Device):** Open `Add Film` -> **`Scan barcode`** -> grant Camera permission:
    1. Scan a **35mm canister DX barcode** -> verify manufacturer, film name, ISO, type, and 1× `35mm` roll with decoded exposure count (`12`/`24`/`36`) populate automatically (or `Select Film` sheet opens if DX code maps to multiple stocks).
    2. Scan a **film box UPC/EAN barcode** (e.g., Kodak Portra 400 5-pack) -> verify format and pack quantity (`5 rolls`) populate automatically.
    3. Scan an **unrelated barcode** (e.g., water bottle) -> verify **`Film not recognized`** alert (`OK` returns to manual entry).
  - **Steps (Simulator):** Tap **`Scan barcode`** -> verify **`Scanner unavailable`** alert.

---

### Suite 3 — Reminder Card Images (Catalog, Camera, Library, Cropper & My Collection)
- [ ] **3.1 Default Image Catalog & Search**
  - **Steps:** In `Add Film`, tap **`Open Catalog`** -> search `"Velvia"` -> tap thumbnail -> verify preview appears with blue selection border -> tap **`x`** badge on thumbnail to clear it.
  - **Expected:** Selected catalog image attaches and clears cleanly.
- [ ] **3.2 Camera Capture, Photo Library & Square Cropper *(Physical Device)***
  - **Steps:** Tap **`Add Image`** -> test both **`Add Image`** (live Camera shutter) and **`Choose from Library`** (`PHPicker`) -> in **`Adjust`** cropper, pinch-to-zoom and drag -> tap **`Done`** -> save film.
  - **Expected:** Cropped square JPEG is saved locally and to the App Group container; card thumbnail displays on `My Films`.
- [ ] **3.3 My Collection Tab (Gallery, Pager & Delete)**
  - **Steps:** Switch to Tab 3 (**`My Collection`**):
    1. Tap **`?`** -> verify help alert -> **`Done`**.
    2. Tap a custom card -> verify full-screen **`1 of N`** pager; swipe left/right between cards -> **`Done`**.
    3. Long-press a card -> **`Delete`** -> **`Cancel`** (keeps image).
    4. Tap **`Edit`** -> select multiple cards -> tap floating red **Trash** button -> confirm **`Delete`**.
  - **Expected:** Custom images are deleted from disk/App Group, linked films gracefully revert to default/no image, and empty state (`No film reminder cards (yet)`) shows when none remain.

---

### Suite 4 — Browsing, Search, Filtering, Sorting, Grouping & Detail Editing
- [ ] **4.1 Cards vs Table View Toggle & Pull-to-Refresh**
  - **Steps:** On `My Films`, switch segmented control between **Cards** (`tablecells`) and **Table** (`list.bullet`) -> pull down on list to refresh.
  - **Expected:** Cards show thumbnails, chips, and format counts; Table shows compact rows with scrollable format columns (`35mm`, `120`, etc.).
- [ ] **4.2 Search, Filter Chips, Mutual Exclusion & Reset**
  - **Steps:**
    1. Type manufacturer, film name, or `"B&W"` into **`Search films...`** -> verify live filtering -> close search.
    2. Tap **Filter** button -> filter by `Manufacturer`, `Type`, `Speed`, `Format`, **`EXPIRED`**, **`FROZEN`**, and **`FRIDGE`** (verify `FROZEN` and `FRIDGE` filters are mutually exclusive; verify `Hide empty` toggle).
    3. Verify active filter count badge on `My Films` toolbar -> re-open Filter and tap **`Reset`**.
  - **Expected:** Filter count badge clears and full inventory returns.
- [ ] **4.3 Sorting & Grouping (`None`, `Manufacturer`, `ISO`)**
  - **Steps:** Open Filter -> test `Sort by` (`Manufacturer`, `Film Type`, `ISO`, `Expiry Date`) in both ascending (`↑`) and descending (`↓`) order -> test `Group by` (`None`, `Manufacturer`, `ISO`).
  - **Expected:** Films reorder accurately (films with expiry dates sort ahead of undated films) and section headers (`Kodak`, `ISO 400`, etc.) appear when grouped.
- [ ] **4.4 Film Detail, Roll/Sheet Editing & Metadata Collision Merge**
  - **Steps:** Tap a film -> in `FilmDetailView`:
    1. Tap pencil icon on a roll group -> adjust quantity, expiry, storage, exposures, comments -> **`Save`** (verify setting quantity to `0` removes that roll group).
    2. For `Sheets` / `Other`, test inline `+`/`-` stepper and pencil **`Edit stock`** sheet (including **`Add expiry date`** multi-date list).
    3. Tap **`...`** (`ellipsis.circle`) -> **`Edit Film`** -> rename film to match an *existing* film's exact `(Manufacturer, Name, Type, Speed)` -> **`Save`**.
  - **Expected:** Both films merge cleanly into a single `GroupedFilm` with combined roll/sheet counts and zero duplicate entries.

---

### Suite 5 — Cameras, Loading Films, Loaded Details & Finished Rolls Workflow
- [ ] **5.1 Manage Cameras & Format Matching**
  - **Steps:** Open Tab 2 (**`Loaded Films`**) -> tap top-left **Camera** icon (`Manage Cameras`) -> tap **`+`** -> add `"Leica M6"` (`35mm`) and `"Hasselblad 500C/M"` (`120`) -> tap `"Leica M6"` to verify `Edit Camera`.
  - **Expected:** Both cameras appear with their format subtitles.
- [ ] **5.2 Load Film (Roll Picker, Quick-Add Camera, Custom ISO & Sheet Quantity)**
  - **Steps:** Swipe left on a film in `My Films` -> **`Load`** (or tap **`Load Film`** in `FilmDetailView`):
    1. Verify format-matched camera appears under **`Suggested`** (or auto-selects when unique).
    2. Open `Select Camera` -> type `"Olympus XA"` in search -> tap **`Add "Olympus XA"`** quick-add row.
    3. When a film has multiple distinct roll batches (e.g., frozen vs non-frozen), verify **`Select Roll`** section appears and lets you choose the specific roll.
    4. Change **`Shoot at ISO`** from `400` to `1600` -> verify orange hint `"Different from film's native ISO"` -> tap **`Load`**.
  - **Expected:** Inventory roll count decrements by 1; roll appears in `Loaded Films` showing **`ISO 1600`** in orange.
- [ ] **5.3 In-Use Deletion Protection (Film & Camera)**
  - **Steps:** While `"HP5 Plus"` is loaded in `"Olympus XA"`:
    1. In `My Films`, swipe left on `"HP5 Plus"` -> **`Delete`**.
    2. In `Manage Cameras`, swipe left on `"Olympus XA"` -> **`Delete`**.
  - **Expected:** Both actions are blocked with **`Cannot Remove Film`** and **`Cannot Delete Camera`** alerts.
- [ ] **5.4 Loaded Roll Details, Comments, Change Date, Partial Sheet Unload & Cancel Load**
  - **Steps:** In `Loaded Films` (`Loaded` segment):
    1. Tap loaded row -> verify `Roll Details` (`On Camera` days, expiry, storage) -> type/edit **`Comments`** -> tap **`Done`**.
    2. Swipe left -> **`Change Date`** -> pick an earlier date -> **`Save`** -> verify relative date & `On Camera` day count update.
    3. Load `3` sheets of `4x5` film -> swipe left on loaded sheets -> tap **`Unload 1 Sheet`** -> verify `2 sheets` remain loaded and `1 sheet` moves to `Finished Rolls`.
    4. Load another roll -> swipe left -> tap **`Remove`** (accidental load).
  - **Expected:** `Remove` deletes the loaded entry *without* creating a finished roll and restores the roll back to `My Films` inventory!
- [ ] **5.5 Finished Rolls Lifecycle (`To develop` -> `In development` -> `Developed` & `Re-load`)**
  - **Steps:** Swipe left on a loaded roll -> **`Finish Roll`** -> switch segmented picker to **`Finished Rolls`**:
    1. Verify badge **`To develop`** and carried-over comment in **`Finished Roll`** detail sheet.
    2. Tap pencil icon next to `Finished` date -> change date -> **`Save`**.
    3. Swipe left -> **`In development`** -> swipe left -> **`Developed`** -> open detail sheet and verify **`Developed`** date row appears.
    4. Test `Search films...` text field and Filter sheet (`Type`, `Status`, `Format`, `Camera`, `Sort by`, `Clear All`).
    5. Swipe left -> **`Re-load`**.
  - **Expected:** Roll moves back to `Loaded` segment and `Statistics -> Finished Rolls` count decrements accordingly.

---

### Suite 6 — Settings, Fridge Mode, Custom Formats, Statistics, Export/Import & StoreKit
- [ ] **6.1 My Films Settings & Fridge Mode**
  - **Steps:** In `Settings`:
    1. Toggle **`Never show empty films`** OFF -> verify 0-quantity films remain visible when `Hide empty` is off.
    2. Toggle **`Always show the table view`** ON -> relaunch app -> verify `My Films` defaults to Table view.
    3. Toggle **`Show expiry date in chip`** ON -> verify film cards show `MM/YYYY` chips (red if expired, primary if valid).
    4. Toggle **`Enable Fridge flag`** ON -> verify `Add/Edit Rolls` switches from a `Frozen` toggle to segmented **`None | Fridge | Frozen`**, `Filter` shows **`FRIDGE`** chip, and `Statistics` shows **`Fridge Films`**.
- [ ] **6.2 Manage Formats (Built-in Toggles & Custom Formats)**
  - **Steps:** `Settings -> Film Formats` -> toggle **`110`** OFF -> tap **`Add Custom Format`** -> add `"Panoramic 6x17"` -> verify `"Panoramic 6x17"` appears in `Add Film -> Format` picker and `"110"` is hidden -> delete `"Panoramic 6x17"` via swipe.
- [ ] **6.3 Statistics & Appearance**
  - **Steps:** Open `Settings -> Statistics` -> cross-check `Total Rolls`, `Total Sheets`, `Unique Films`, `Finished Rolls`, `Expired Films`, `Frozen Films`, `Fridge Films`, `By Type`, and `By Format` against inventory. Open `Settings -> Appearance` -> verify `System`, `Light`, and `Dark` modes immediately update color scheme.
- [ ] **6.4 Export & Import Inventory (JSON & CSV)**
  - **Steps:** Open `Settings -> Export or Import Inventory`:
    1. Export **JSON** via **`Export & Share`** -> Save to Files.
    2. Export **CSV** via **`Export & Share`** -> Save to Files (open in Numbers/Excel to verify `# INVENTORY`, `# LOADED FILMS`, `# FINISHED FILMS`, `# CAMERAS` sections).
    3. Switch to **`Import`** tab -> **`Choose File`** -> select exported JSON/CSV -> verify **`Review Import`** summary sheet -> tap **`Import`**.
  - **Expected:** Settings dismisses, switches to `My Films`, shows **`Import completed successfully`** toast; existing loaded/finished rolls and cameras are not duplicated.
- [ ] **6.5 About, Legal & StoreKit Support ("Buy Me a Coffee")**
  - **Steps:**
    1. Open `Settings -> About` -> verify version, **`Privacy Policy`**, **`Terms of Service`**, and **`Contact me`** (`mailto:hello@halbe.no` on device; `"Email Not Available"` alert on Simulator).
    2. Open `Settings -> Buy Me a Coffee` (with `Configuration.storekit` active in Xcode scheme) -> tap **`Buy Me a Coffee ($1.99)`** -> confirm **`Yes, Support FilmStock`** -> complete Xcode StoreKit test sheet -> verify **`Thank You!`** alert -> tap **`Restore Purchases`**.

---

### Suite 7 — Home Screen Widget, AppIntents & Deep Links *(Simulator or Device)*
- [ ] **7.1 Empty Widget & Deep Link**
  - **Steps:** With 0 loaded films, add the small **`Loaded Films`** FilmStock widget to the iOS Home Screen -> verify `"No Films Loaded"` state -> tap widget.
  - **Expected:** App opens directly onto Tab 2 (**`Loaded Films`**).
- [ ] **7.2 Populated Widget, Cycling Intents & Edit Widget Configuration**
  - **Steps:** Load 2+ films with different reminder cards and custom ISOs -> return to Home Screen:
    1. Verify widget displays the latest loaded film's reminder card.
    2. Tap **`<`** and **`>`** chevron buttons on the widget -> verify widget cycles through loaded films inline without launching the app (`NextFilmIntent` / `PreviousFilmIntent`).
    3. Long-press widget -> **`Edit Widget`** -> toggle **`Show Film Info`** ON and test **`Position`** (`Top` vs `Bottom`) -> verify camera name + `ISO <effectiveISO>` pill overlay appears.
    4. Tap the widget body -> verify app opens Tab 2 (`Loaded Films`) and automatically presents **`Roll Details`** for that specific roll (`filmstock://loadedfilms?id=<id>`).

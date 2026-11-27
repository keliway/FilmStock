# Analog FilmStock — Full End-to-End Test Script & QA Checklist

This document covers **100% of Analog FilmStock's features** end-to-end, combining:
1. **Automated Test Execution** (`FilmStockTests` Swift Testing unit/integration suite + `FilmStockUITests` XCUITest UI suite + `run_e2e_tests.sh`).
2. **Non-Destructive Manual QA Test Script** designed to be run **directly on your real iPhone with your existing film library, cameras, loaded rolls, and finished roll history** — without wiping or polluting your collection.

---

## Quick Start — Running Automated Tests

| Goal | Command / Action |
| :--- | :--- |
| **Run everything in Xcode** | Select scheme **`FilmStock`** -> press **`Cmd + U`** |
| **Run full suite from Terminal** | `bash run_e2e_tests.sh` |
| **Run Unit & Integration tests only** | `bash run_e2e_tests.sh --unit` |
| **Run End-to-End UI tests only** | `bash run_e2e_tests.sh --ui` |

> **Data Safety Guarantee (Automated Tests):** All automated UI tests launch the app with `-UITesting`, which switches SwiftData to an **in-memory store**, isolates custom reminder card photos into a temporary directory, and resets settings in-process so real user data on Simulator/device is never modified.

---

## Automated Coverage Matrix (18 Automated Tests: 11 Unit/Integration + 7 E2E UI)

| Area | Unit / Integration (`FilmStockTests`) | UI E2E (`FilmStockUITests`) |
| :--- | :---: | :---: |
| Models, `Codable`, Storage Mutual Exclusion (`Frozen` vs `Fridge`), Bulk Roll (`-2`) | ✅ | ✅ |
| Expiry Date Parsing (`YYYY`, `MMYYYY`, `M/YYYY`, `MM/YY`, `YYYY-MM-DD`, leap years) & Validation | ✅ | ✅ |
| First-Launch Welcome Onboarding (4 pages, `Skip`, `Get Started`) + Sequential Tooltips | ✅ | ✅ |
| Post-Update `What's New` Sheet (Automatic & Settings manual trigger) | — | ✅ |
| Built-in & Custom Manufacturers (Pinned order, Add, Search, Duplicate/In-Use Delete Guard) | ✅ | ✅ |
| Add Film, Auto-Metadata Detection (`manufacturers.json`), Roll Batch Splitting & Sheet Merging | ✅ | ✅ |
| Film Detail, Edit Film Metadata, Collision Merge, Roll Group Edit, Inline Sheet Controls | ✅ | ✅ |
| Legacy v1.x/v2.x Library Upgrade, Roll Editing, Camera Delete (`#86`), Stock Delete History Guard & Legacy Backup Import | ✅ | ✅ |
| Search, Multi-Facet Filtering, Filter Badge, Reset, Sorting, Group By & Cards/Table View Toggle | — | ✅ |
| Manage Cameras (Add, Edit, Format Matching, Auto-Selection, In-Use Delete Protection) | ✅ | ✅ |
| Load Film (Roll Picker, Sheet Quantity, Custom `Shoot at ISO`, Cannot-Delete-Loaded Guard) | ✅ | ✅ |
| Loaded Films (Roll Details, Live Comment Sync, Change Date, Partial Sheet Unload, Finish, Remove) | ✅ | ✅ |
| Finished Rolls (Status `To develop` -> `In development` -> `Developed`, Edit Date, Filter, `Re-load`) | ✅ | ✅ |
| My Collection (Custom Reminder Cards Grid, Paging Viewer, Multi-Select Delete, Unreferenced Cleanup) | ✅ | ✅ |
| Settings (Fridge Mode, Expiry Chip, Table Default, Custom Formats, Statistics, Appearance, Legal) | ✅ | ✅ |
| Export & Import Round-Trip (JSON & RFC-4180 CSV across Inventory, Loaded, Finished, Cameras) | ✅ | ✅ (UI) |

---

## Manual End-to-End QA Script (For Your Real Library on Device)

This script is written so you can run every check **on top of your real, long-lived library** (including films, cameras, and finished rolls added in earlier `v1.x` / `v2.x` releases) and end with your library in the **exact same state** you started.

### Golden Rules for Testing on a Live Library
1. **Prefix temporary QA items with `QA-`** (e.g., Manufacturer `QA-Lab`, Film `QA-Test 400`, Camera `QA-Camera`, Format `QA-6x17`) so they never merge into your real stocks and can be deleted cleanly at the end of each section.
2. **Never finish a QA roll unless testing `Finished Rolls`:** Remember that `Finished Rolls` has `Re-load` (not permanent delete). To test `Loaded -> Finish -> Status -> Re-load -> Remove` without leaving a permanent entry in your real history, always **`Re-load`** the QA roll at the end of Suite 5 and swipe **`Remove`** on `Loaded Films`!
3. **Take a safety backup first** (Step 0.1 below) — which simultaneously tests JSON/CSV export on your real data.

---

### Suite 0 — Pre-Flight Backup & Post-Update Integrity Check (Existing Library)
- [ ] **0.1 Real-Library Safety Backup (Tests Export on Real Data)**
  - **Steps:** Open **`Settings -> Export or Import Inventory`** -> export **JSON** to Files (e.g., `FilmStock_PreQA_Backup.json`) and export **CSV** to Files.
  - **Expected:** Both files generate immediately without errors. Open the CSV in Quick Look / Numbers and confirm your real `# INVENTORY`, `# LOADED FILMS`, `# FINISHED FILMS`, and `# CAMERAS` counts look right.
- [ ] **0.2 Post-Update Launch & `What's New` Sheet**
  - **Steps:** Install the new build **over** your existing app on iPhone -> launch app:
    1. Verify **`What's New`** presents automatically if `whatsNewVersion` was bumped (or open **`Settings -> What's New`** manually) -> tap **`Continue`**.
    2. Record your baseline numbers in **`Settings -> Statistics`**:
       - `Total Rolls`: `____` | `Total Sheets`: `____` | `Unique Films`: `____` | `Finished Rolls`: `____`
  - **Expected:** Zero missing films, zero duplicated rolls, custom reminder card photos still appear on your cards, and `Loaded Films` / `Finished Rolls` tabs open without delay or crash.
  - *(Note: First-install Welcome onboarding & tooltips require a clean container and are already verified automatically on Simulator by `testOnboardingWelcomeTooltipsAndWhatsNew()` — only test manually on a Simulator if desired.)*

---

### Suite 1 — Verifying & Updating Existing / Legacy (`v1.x`–`v2.x`) Library Items
- [ ] **1.1 Inspect & Non-Destructively Edit an Old Film From Your Existing Stock**
  - **Steps:** Pick one of the oldest films in your `My Films` list -> tap into `FilmDetailView`:
    1. Tap the pencil icon on an existing roll group -> verify existing expiry date (even if originally saved as `M/YYYY` or `MMYYYY`), frozen/fridge state, exposures, and comments populate accurately.
    2. Add ` (QA check)` to **`Comments`** (or toggle `Frozen` ON) -> tap **`Save`** -> verify detail view & card update immediately -> re-open pencil sheet, revert your change back to original, and tap **`Save`**.
  - **Expected:** Legacy rolls save cleanly with no false expiry-validation errors, and roll counts stay identical.
- [ ] **1.2 Inspect Existing Loaded & Finished History**
  - **Steps:** Switch to Tab 2 (**`Loaded Films`**):
    1. Tap an **existing loaded roll** (if you have one loaded) -> verify `Roll Details` shows camera name, loaded date, `On Camera` day count, ISO, expiry/storage badges, and comments -> tap **`Done`**.
    2. Switch segment to **`Finished Rolls`** -> scroll through your oldest finished rolls (including any whose camera or active stock you deleted months ago) -> tap an old finished roll to open **`Finished Roll`** details -> tap **`Done`**.
  - **Expected:** Every historical roll displays its film name, reminder card thumbnail, camera snapshot, status badge (`To develop` / `In development` / `Developed`), and comments without `Unavailable` placeholders or crashes.

---

### Suite 2 — Browsing, Search, Filtering, Sorting & Grouping on Real Data
- [ ] **2.1 Cards vs Table View & Pull-to-Refresh**
  - **Steps:** On `My Films`, toggle between **Cards** (`tablecells`) and **Table** (`list.bullet`) -> scroll horizontally across format columns in Table view -> pull down to refresh -> switch back to your preferred view.
  - **Expected:** Total roll count in header stays identical across both views.
- [ ] **2.2 Search & Multi-Facet Filter Combinations on Your Collection**
  - **Steps:**
    1. Search by manufacturer (e.g., `"Kodak"`), film name, and type (`"B&W"` / `"Slide"`) -> clear search (`Close`).
    2. Open **Filter** -> test filtering your real collection by `Manufacturer`, `Type`, `Speed`, `Format`, **`EXPIRED`**, **`FROZEN`**, and **`FRIDGE`** (if Fridge flag is enabled; verify `FROZEN` and `FRIDGE` cannot both be active at once).
    3. Toggle **`Hide empty`** OFF and ON -> check active filter count badge on `My Films` -> open Filter and tap **`Reset`**.
  - **Expected:** Every filter combination matches your real inventory accurately, and **`Reset`** restores your exact baseline roll count.
- [ ] **2.3 Sorting & Grouping (`None`, `Manufacturer`, `ISO`)**
  - **Steps:** Open **Filter** -> test `Sort by` (`Manufacturer`, `Film Type`, `ISO`, `Expiry Date`) in ascending (`↑`) and descending (`↓`) order -> test `Group by` (`None`, `Manufacturer`, `ISO`) -> restore your preferred sort/grouping.
  - **Expected:** Undated films sort cleanly after dated films in `Expiry Date` mode; group section headers match every film beneath them.

---

### Suite 3 — Adding Sandbox (`QA-`) Films, Manufacturers, Sheets & Barcode Scanning
*(All items created here use `QA-` names so they never touch your real films and are deleted at Step 3.6.)*
- [ ] **3.1 Validation & Built-In Auto-Metadata Check (Without Saving)**
  - **Steps:** Tap **`+`** on `My Films`:
    1. Verify **`Save`** is disabled when empty.
    2. Select **`Ilford`**, type **`HP5 Plus`** -> verify `Type` auto-sets to **`B&W`**, `Speed` wheel scrolls to **`ISO 400`**, and the default `Ilford HP5 Plus` reminder card appears -> tap **`Cancel`** (do not save into your real HP5 stock).
- [ ] **3.2 Custom Manufacturer Lifecycle & Protection (`QA-Lab`)**
  - **Steps:** Tap **`+`** -> **`Manufacturer`** -> tap **`+`**:
    1. Type `"Kodak"` -> verify duplicate warning (`"This manufacturer already exists."`) and disabled **`Add`**.
    2. Type **`QA-Lab`** -> tap **`Add`**.
    3. Enter Name **`QA-Test 400`** -> tap **`Add Rolls`**:
       - Test invalid dates: `"123"` (`Date must be YYYY or MM/YYYY`), `"132028"` (`Month must be between 01 and 12`), `"1940"` (`Year must be between 1950 and 2100`).
       - Enter valid **`082028`** (auto-formats to `08/2028`), set `Rolls: 2`, set `Exposures` to **`Custom` -> `18`**, toggle **`Frozen`**, add comment `"QA batch"`, tap **`Save`** on roll sheet, then **`Save`** film.
    4. Tap **`+`** -> **`Manufacturer`** -> search **`QA-Lab`** -> swipe left on `QA-Lab` -> **`Delete`** -> verify **`Cannot Delete Manufacturer`** alert blocks deletion while `QA-Test 400` exists -> cancel out of `Add Film`.
- [ ] **3.3 Large Format Sheets & Metadata Collision Merge (`QA-Sheet` -> `QA-Test 400`)**
  - **Steps:**
    1. Tap **`+`** -> select **`QA-Lab`**, Name **`QA-Sheet`**, ISO `400`, Type `B&W` -> **`Add Rolls`** -> Format **`4x5`**, `Sheets: 5` -> **`Save`** batch & **`Save`** film.
    2. Open **`QA-Lab QA-Sheet`** -> test inline `+`/`-` sheet stepper and pencil **`Edit stock`** (including **`Add expiry date`** multi-date row) -> **`Save`**.
    3. Tap **`...`** (`ellipsis.circle`) -> **`Edit Film`** -> rename `QA-Sheet` to **`QA-Test 400`** -> **`Save`**.
  - **Expected:** `QA-Sheet` merges cleanly into **`QA-Lab QA-Test 400`**, which now shows **both** the `35mm` rolls and `4x5` sheets under one film!
- [ ] **3.4 DX Canister & Box Barcode Scanner *(Physical Device — Cancel or Use QA Delete)***
  - **Steps:** Tap **`+`** -> **`Scan barcode`**:
    1. Scan a **35mm canister DX barcode** -> verify manufacturer, film name, ISO, type, and 1× `35mm` roll + exposure count populate (or `Select Film` picker appears for shared DX codes) -> tap **`Cancel`** so you don't add extra stock to your real library.
    2. Tap **`+`** -> **`Scan barcode`** -> scan a **film box UPC/EAN barcode** -> verify format & multi-pack roll count populate -> tap **`Cancel`**.
    3. Scan a **non-film barcode** (e.g., book/bottle) -> verify **`Film not recognized`** alert.

---

### Suite 4 — Reminder Card Images (Catalog, Camera, Cropper & My Collection)
- [ ] **4.1 Catalog, Camera Capture & Cropper on Your Sandbox `QA-Test 400` Film *(Physical Device)***
  - **Steps:** Open **`QA-Lab QA-Test 400`** -> **`...` -> `Edit Film`**:
    1. Tap **`Open Catalog`** -> search `"Velvia"` -> select thumbnail -> tap **`x`** badge on preview to clear.
    2. Tap **`Add Image`** -> take a quick photo with **Camera** (or **`Choose from Library`**) -> pinch/drag in **`Adjust`** square cropper -> tap **`Done`** -> tap **`Save`**.
  - **Expected:** Custom cropped card appears on `QA-Lab QA-Test 400` without affecting any of your real reminder cards.
- [ ] **4.2 My Collection Tab (Inspect Real Cards + Delete Only the `QA-` Card)**
  - **Steps:** Switch to Tab 3 (**`My Collection`**):
    1. Tap **`?`** -> verify help alert -> **`Done`**.
    2. Tap any card to verify the full-screen **`1 of N`** pager -> swipe between cards -> **`Done`**.
    3. Tap **`Edit`** -> select **only** the temporary photo you just took for `QA-Test 400` -> tap floating red **Trash** button -> confirm **`Delete`**.
  - **Expected:** Only the `QA-Test 400` photo is removed; all of your real custom reminder cards in `My Collection` remain untouched.

---

### Suite 5 — Cameras, Load Film, Roll Details, Finished Rolls & Zero-Trace Cleanup
*(Uses `QA-Lab QA-Test 400` + `QA-Camera` and cleans up via `Re-load` -> `Remove` so zero test entries remain in your real `Finished Rolls` history!)*
- [ ] **5.1 Add Sandbox Camera (`QA-Camera`)**
  - **Steps:** On Tab 2 (**`Loaded Films`**), tap top-left **Camera** icon (`Manage Cameras`) -> **`+`** -> Name **`QA-Camera`**, Format **`35mm`** -> **`Add`** -> tap `QA-Camera` to test `Edit Camera` -> **`Done`**.
- [ ] **5.2 Load `QA-Test 400` Into `QA-Camera` With Custom ISO**
  - **Steps:** Open **`QA-Lab QA-Test 400`** -> tap **`Load Film`**:
    1. Verify **`QA-Camera`** appears under **`Suggested`** `35mm` cameras -> select **`QA-Camera`**.
    2. Change **`Shoot at ISO`** from `400` to **`1600`** -> verify orange hint `"Different from film's native ISO"` -> tap **`Load`**.
  - **Expected:** `QA-Test 400` roll count drops by 1; `Loaded Films` shows `QA-Lab QA-Test 400` in `QA-Camera` at **`ISO 1600`** alongside any real loaded films you already had.
- [ ] **5.3 In-Use Deletion Protection (Film & Camera)**
  - **Steps:**
    1. In `My Films`, swipe left on **`QA-Lab QA-Test 400`** -> **`Delete`** -> verify **`Cannot Remove Film`** alert blocks deletion.
    2. In `Manage Cameras`, swipe left on **`QA-Camera`** -> **`Delete`** -> verify **`Cannot Delete Camera`** alert blocks deletion.
- [ ] **5.4 Loaded Details, Comments & Change Date**
  - **Steps:** In `Loaded Films`, tap **`QA-Lab QA-Test 400`** -> edit **`Comments`** (`"QA batch +1"`) -> **`Done`**. Swipe left on `QA-Lab QA-Test 400` -> **`Change Date`** -> pick yesterday -> **`Save`**.
- [ ] **5.5 Finish -> Status Transitions -> Filter -> `Re-load` -> `Remove` (Leaves Zero History Trace!)**
  - **Steps:**
    1. Swipe left on `QA-Lab QA-Test 400` -> **`Finish Roll`** -> switch to **`Finished Rolls`**.
    2. Tap `QA-Lab QA-Test 400` -> verify carried-over comment (`"QA batch +1"`) -> tap pencil icon next to `Finished` date -> **`Save`** -> **`Done`**.
    3. Swipe left -> **`In development`** -> swipe left -> **`Developed`** -> test search/filter sheet on `Finished Rolls` -> reset filter.
    4. **Clean up history:** Swipe left on `QA-Lab QA-Test 400` in `Finished Rolls` -> tap **`Re-load`** (moves it back to `Loaded` and decrements `Finished Rolls` counter back to your baseline!).
    5. Switch to **`Loaded`** segment -> swipe left on `QA-Lab QA-Test 400` -> tap **`Remove`** (cancels load and returns the roll to `QA-Test 400`).
- [ ] **5.6 Delete Sandbox Film, Camera & Custom Manufacturer**
  - **Steps:**
    1. In `My Films`, swipe left on **`QA-Lab QA-Test 400`** -> **`Delete`**.
    2. In `Loaded Films -> Manage Cameras`, swipe left on **`QA-Camera`** -> **`Delete`**.
    3. Tap **`+`** on `My Films` -> **`Manufacturer`** -> search **`QA-Lab`** -> swipe left -> **`Delete`** -> cancel `Add Film`.
  - **Expected:** All `QA-` sandbox records are gone, and **`Settings -> Statistics`** matches your exact Step 0.2 baseline (`Total Rolls`, `Total Sheets`, `Unique Films`, `Finished Rolls`).

---

### Suite 6 — Settings, Fridge Mode, Custom Formats, Appearance & StoreKit
- [ ] **6.1 Non-Destructive Settings Toggles**
  - **Steps:** Open **`Settings`**:
    1. Toggle **`Show expiry date in chip`** ON/OFF -> check your film cards on `My Films`.
    2. Toggle **`Enable Fridge flag`** ON -> verify `Statistics` shows **`Fridge Films`**, `Filter` shows **`FRIDGE`**, and roll edit sheets show **`None | Fridge | Frozen`** -> restore your preferred toggle states.
    3. Open **`Film Formats`** -> add custom format **`QA-6x17`** -> verify it appears -> swipe left to **`Delete`** `QA-6x17` (avoid toggling off built-in formats you actively use, or re-enable them right after checking).
    4. Open **`Appearance`** -> test `Dark`, `Light`, `System` -> restore your preference.
- [ ] **6.2 About, Legal & StoreKit ("Buy Me a Coffee")**
  - **Steps:**
    1. Open **`Settings -> About`** -> check version string, **`Privacy Policy`**, **`Terms of Service`**, and **`Contact me`** (`mailto:hello@halbe.no`).
    2. Open **`Settings -> Buy Me a Coffee`** -> verify product price loads (test purchase via Xcode `Configuration.storekit` or Sandbox Apple ID; cancel sheet on App Store production if not purchasing) -> test **`Restore Purchases`**.
- [ ] **6.3 Import Preview Verification (Without Duplicating Real Stock)**
  - **Steps:** Open **`Settings -> Export or Import Inventory`** -> **`Import`** tab -> **`Choose File`** -> pick the `FilmStock_PreQA_Backup.json` you exported in Step 0.1 -> inspect the **`Review Import`** summary sheet to confirm counts match your library -> tap **`Cancel`** on the preview sheet!
  - *(Why `Cancel`? Importing inventory into an already-populated database adds inventory quantities on top of existing stock; tapping `Cancel` verifies the full parser + preview UI on your real backup file without doubling your roll counts.)*

---

### Suite 7 — Home Screen Widget, AppIntents & Deep Links *(On Your Real Loaded Films)*
- [ ] **7.1 Widget Display, Inline Cycling & Configuration**
  - **Steps:** Add (or inspect your existing) **`Loaded Films`** FilmStock widget on your iPhone Home Screen:
    1. Verify your currently loaded film's reminder card (or `"No Films Loaded"` if none are loaded) renders sharply.
    2. If you have 2+ films loaded, tap **`<`** and **`>`** on the widget -> verify it cycles between your loaded cameras inline without opening the app.
    3. Long-press widget -> **`Edit Widget`** -> toggle **`Show Film Info`** ON and test **`Top`** vs **`Bottom`** pill position -> verify camera name + `ISO <effectiveISO>` overlay.
- [ ] **7.2 Deep Link Navigation**
  - **Steps:** Tap the widget body -> verify FilmStock opens directly onto Tab 2 (**`Loaded Films`**) and automatically opens **`Roll Details`** for the displayed roll (`filmstock://loadedfilms?id=<id>`).

//
//  FilmStockUITests.swift
//  FilmStockUITests
//
//  End-to-End Automated UI Test Suite for Analog FilmStock.
//  Uses `-UITesting` in-memory SwiftData & isolated temp storage so user data is never modified.
//

import XCTest

@MainActor
final class FilmStockUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func makeApp(extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ] + extraArgs
        return app
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 6, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            element.waitForExistence(timeout: timeout),
            "Expected element \(element) to exist within \(timeout)s",
            file: file,
            line: line
        )
    }

    /// Swipes vertically near the trailing margin so centered wheel pickers (like ISO Speed) aren't accidentally spun.
    private func scrollDownForm(in app: XCUIApplication) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.75))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.25))
        start.press(forDuration: 0.02, thenDragTo: end)
    }

    private func scrollToAndTap(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 5) {
        let target = element.firstMatch
        var attempts = 0
        while (!target.exists || !target.isHittable) && attempts < maxSwipes {
            scrollDownForm(in: app)
            attempts += 1
        }
        XCTAssertTrue(target.waitForExistence(timeout: 3), "Element \(target) not found after scrolling")
        target.tap()
    }

    private func toggleSwitch(_ toggle: XCUIElement) {
        waitFor(toggle)
        let innerSwitch = toggle.switches.firstMatch
        if innerSwitch.exists && innerSwitch.isHittable {
            innerSwitch.tap()
        } else {
            let thumb = toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            thumb.tap()
        }
    }

    private func incrementFirstStepper(in app: XCUIApplication, times: Int = 1) {
        let stepper = app.steppers.firstMatch
        waitFor(stepper)
        for _ in 0..<times {
            let incrementBtn = stepper.buttons["Increment"]
            if incrementBtn.exists {
                incrementBtn.tap()
            } else {
                stepper.buttons.element(boundBy: 1).tap()
            }
        }
    }

    private func quickAddFilm(
        in app: XCUIApplication,
        manufacturer: String,
        name: String,
        format: String? = nil,
        extraRolls: Int = 0,
        expiry: String? = nil,
        frozen: Bool = false,
        comment: String? = nil
    ) {
        let addBtn = app.buttons["browse.addFilmButton"]
        waitFor(addBtn)
        addBtn.tap()

        let selectMfr = app.staticTexts["Select Manufacturer"]
        waitFor(selectMfr)
        selectMfr.tap()

        let searchField = app.searchFields["Search manufacturer"]
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText(manufacturer)
        }
        let mfrButton = app.buttons[manufacturer].firstMatch
        if mfrButton.waitForExistence(timeout: 3) {
            mfrButton.tap()
        } else {
            app.staticTexts[manufacturer].firstMatch.tap()
        }

        let nameField = app.textFields["Name"]
        waitFor(nameField)
        nameField.tap()
        nameField.typeText(name + "\n")

        let addRollsBtn = app.buttons["Add Rolls"]
        scrollToAndTap(addRollsBtn, in: app)

        if let format, format != "35mm" {
            let formatPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Format'")).firstMatch
            if formatPicker.waitForExistence(timeout: 3) {
                formatPicker.tap()
                let optionBtn = app.buttons[format].firstMatch
                if optionBtn.waitForExistence(timeout: 3) {
                    optionBtn.tap()
                } else {
                    app.staticTexts[format].firstMatch.tap()
                }
            }
        }

        if extraRolls > 0 {
            incrementFirstStepper(in: app, times: extraRolls)
        }

        if let expiry {
            let expiryField = app.textFields["MMYYYY or YYYY"]
            scrollToAndTap(expiryField, in: app)
            expiryField.typeText(expiry)
        }

        if frozen {
            let frozenToggle = app.switches["Film is frozen"]
            if !frozenToggle.exists || !frozenToggle.isHittable {
                scrollDownForm(in: app)
            }
            if frozenToggle.waitForExistence(timeout: 2) {
                toggleSwitch(frozenToggle)
            }
        }

        if let comment {
            scrollDownForm(in: app)
            let commentField = app.textViews.firstMatch.exists
                ? app.textViews.firstMatch
                : app.textFields["Add a note about this roll…"]
            if commentField.waitForExistence(timeout: 2) {
                commentField.tap()
                commentField.typeText(comment)
            }
        }

        // Save RollBatchSheet
        app.navigationBars.buttons["Save"].firstMatch.tap()

        // Save AddFilmView
        let saveFilmBtn = app.navigationBars["Add Film"].buttons["Save"]
        waitFor(saveFilmBtn)
        saveFilmBtn.tap()
    }

    // MARK: - 1. Onboarding, Tooltips & What's New

    func testOnboardingWelcomeTooltipsAndWhatsNew() throws {
        // Part A: First-launch Welcome pages + sequential Onboarding Tooltips
        let onboardingApp = makeApp(extraArgs: ["-UITestOnboarding"])
        onboardingApp.launch()

        waitFor(onboardingApp.staticTexts["Welcome to FilmStock!"])
        let skipButton = onboardingApp.buttons["Skip"]
        waitFor(skipButton)
        skipButton.tap()

        // Skip jumps to final page ("Custom Film Reminder Cards") with "Get Started"
        waitFor(onboardingApp.staticTexts["Custom Film Reminder Cards"])
        let getStartedBtn = onboardingApp.buttons["Get Started"]
        waitFor(getStartedBtn)
        getStartedBtn.tap()

        // Tooltip 1: Add Your First Film
        waitFor(onboardingApp.staticTexts["Add Your First Film"])
        onboardingApp.buttons["Got it"].firstMatch.tap()

        // Tooltip 2: Filter Your Films
        waitFor(onboardingApp.staticTexts["Filter Your Films"])
        onboardingApp.buttons["Got it"].firstMatch.tap()

        // Empty state visible on My Films
        waitFor(onboardingApp.staticTexts["No Films Yet"])
        XCTAssertTrue(onboardingApp.staticTexts["Add your first film to get started!"].exists)
        onboardingApp.terminate()

        // Part B: Post-update What's New sheet
        let whatsNewApp = makeApp(extraArgs: ["-UITestWhatsNew"])
        whatsNewApp.launch()

        waitFor(whatsNewApp.staticTexts["What's New"])
        XCTAssertTrue(whatsNewApp.staticTexts["Comments on Loaded Films"].exists)
        let continueBtn = whatsNewApp.buttons["Continue"]
        waitFor(continueBtn)
        continueBtn.tap()

        waitFor(whatsNewApp.navigationBars["My Films"])
    }

    // MARK: - 2. Add Film, Barcode Alert, Custom Manufacturer, Image Catalog, Validation & Detail Editing

    func testAddFilmCatalogCustomManufacturerValidationAndDetailEditing() throws {
        let app = makeApp()
        app.launch()

        let addBtn = app.buttons["browse.addFilmButton"]
        waitFor(addBtn)
        addBtn.tap()

        // Save button is disabled until required fields + rolls are added
        let saveFilmBtn = app.navigationBars["Add Film"].buttons["Save"]
        waitFor(saveFilmBtn)
        XCTAssertFalse(saveFilmBtn.isEnabled)

        // Barcode scanner on Simulator gracefully shows "Scanner unavailable" alert
        let scanBtn = app.buttons["Scan barcode"]
        waitFor(scanBtn)
        scanBtn.tap()
        let scannerAlert = app.alerts["Scanner unavailable"]
        waitFor(scannerAlert)
        scannerAlert.buttons["OK"].tap()

        // Custom Manufacturer add + delete flow, then choose Kodak
        app.staticTexts["Select Manufacturer"].tap()
        let addMfrBtn = app.buttons["manufacturerPicker.addButton"]
        waitFor(addMfrBtn)
        addMfrBtn.tap()

        let mfrAlert = app.alerts["Add Manufacturer"]
        waitFor(mfrAlert)
        let mfrField = mfrAlert.textFields.firstMatch
        mfrField.tap()
        mfrField.typeText("TestCustomLab")
        mfrAlert.buttons["Add"].tap()

        // Verify custom manufacturer was selected and popped back, then switch to Kodak & delete custom manufacturer
        waitFor(app.staticTexts["TestCustomLab"])
        app.staticTexts["TestCustomLab"].tap()

        let mfrSearch = app.searchFields["Search manufacturer"]
        waitFor(mfrSearch)
        mfrSearch.tap()
        mfrSearch.typeText("TestCustomLab")

        let customMfrRow = app.buttons["TestCustomLab"].firstMatch
        waitFor(customMfrRow)
        customMfrRow.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }

        // Replace search text with Kodak
        mfrSearch.tap()
        if let val = mfrSearch.value as? String, !val.isEmpty {
            mfrSearch.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: val.count))
        }
        mfrSearch.typeText("Kodak")
        waitFor(app.buttons["Kodak"].firstMatch)
        app.buttons["Kodak"].firstMatch.tap()

        // Enter known film name ("Portra 400") -> auto-populates metadata & default image
        let nameField = app.textFields["Name"]
        waitFor(nameField)
        nameField.tap()
        nameField.typeText("Portra 400\n")

        // Open Image Catalog, verify Default Catalog & My Photos tabs, dismiss
        let catalogBtn = app.buttons["Open Catalog"]
        scrollToAndTap(catalogBtn, in: app)
        waitFor(app.navigationBars["Image Catalog"])
        let myPhotosSeg = app.segmentedControls.buttons["My Photos"]
        if myPhotosSeg.waitForExistence(timeout: 2) {
            myPhotosSeg.tap()
            waitFor(app.staticTexts["No film card photos"])
            app.segmentedControls.buttons["Default Catalog"].tap()
        }
        app.navigationBars["Image Catalog"].buttons["Done"].tap()

        // Add Rolls with expiry validation test first
        scrollToAndTap(app.buttons["Add Rolls"], in: app)
        let expiryField = app.textFields["MMYYYY or YYYY"]
        waitFor(expiryField)
        expiryField.tap()
        expiryField.typeText("132028")
        app.navigationBars.buttons["Save"].firstMatch.tap()

        // Validation error appears and keeps sheet open
        waitFor(app.staticTexts["Month must be between 01 and 12"])

        // Clear invalid date and enter valid 082028 (auto-formats to 08/2028)
        if let currentVal = expiryField.value as? String {
            let deletes = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentVal.count)
            expiryField.typeText(deletes)
        }
        expiryField.typeText("082028")
        incrementFirstStepper(in: app, times: 1) // 2 rolls

        let frozenToggle = app.switches["Film is frozen"]
        if !frozenToggle.exists || !frozenToggle.isHittable {
            scrollDownForm(in: app)
        }
        toggleSwitch(frozenToggle)

        app.navigationBars.buttons["Save"].firstMatch.tap()

        // Save film
        XCTAssertTrue(saveFilmBtn.waitForExistence(timeout: 3))
        XCTAssertTrue(saveFilmBtn.isEnabled)
        saveFilmBtn.tap()

        // Verify card on My Films
        waitFor(app.staticTexts["Kodak Portra 400"])
        XCTAssertTrue(app.staticTexts["2 rolls"].exists)
        XCTAssertTrue(app.staticTexts["FROZEN"].exists)

        // Push into FilmDetailView
        app.staticTexts["Kodak Portra 400"].firstMatch.tap()
        waitFor(app.navigationBars["Kodak Portra 400"])
        XCTAssertTrue(app.staticTexts["ISO 400"].exists)

        // Edit roll group quantity from 2 -> 3
        let editRollGroupBtn = app.buttons["filmDetail.editRollGroupButton"].firstMatch
        waitFor(editRollGroupBtn)
        editRollGroupBtn.tap()
        incrementFirstStepper(in: app, times: 1)
        app.navigationBars.buttons["Save"].firstMatch.tap()
        waitFor(app.staticTexts["3 rolls"])

        // Inline Add Rolls -> add 4x5 sheet film
        scrollToAndTap(app.buttons["Add Rolls"], in: app)
        let formatPicker = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Format'")).firstMatch
        waitFor(formatPicker)
        formatPicker.tap()
        if app.buttons["4x5"].waitForExistence(timeout: 3) {
            app.buttons["4x5"].tap()
        } else {
            app.staticTexts["4x5"].firstMatch.tap()
        }
        incrementFirstStepper(in: app, times: 4) // 5 sheets
        app.navigationBars.buttons["Save"].firstMatch.tap()
        waitFor(app.staticTexts["Sheets"])

        // Edit Film metadata via top-right ellipsis menu
        let moreMenu = app.buttons["filmDetail.moreMenu"]
        waitFor(moreMenu)
        moreMenu.tap()
        let editFilmMenuBtn = app.buttons["Edit Film"]
        waitFor(editFilmMenuBtn)
        editFilmMenuBtn.tap()

        let editNameField = app.textFields["Name"]
        waitFor(editNameField)
        editNameField.tap()
        editNameField.typeText(" Pro\n")
        app.navigationBars["Edit Film"].buttons["Save"].tap()

        waitFor(app.navigationBars["Kodak Portra 400 Pro"])
    }

    // MARK: - 3. Search, Filter, Sort, Grouping & Cards/Table View Modes

    func testSearchFilterSortGroupAndViewModes() throws {
        let app = makeApp()
        app.launch()

        // Seed 2 distinct films:
        // 1) Ilford HP5 Plus (B&W, ISO 400, 35mm, expired 01/2020, Frozen)
        quickAddFilm(
            in: app,
            manufacturer: "Ilford",
            name: "HP5 Plus",
            expiry: "012020",
            frozen: true
        )
        // 2) Kodak Ektar 100 (Color, ISO 100, 120, valid 12/2029)
        quickAddFilm(
            in: app,
            manufacturer: "Kodak",
            name: "Ektar 100",
            format: "120",
            expiry: "122029",
            frozen: false
        )

        waitFor(app.staticTexts["Ilford HP5 Plus"])
        waitFor(app.staticTexts["Kodak Ektar 100"])

        // Toggle Cards <-> Table/List view mode
        let viewModePicker = app.segmentedControls["browse.viewModePicker"]
        waitFor(viewModePicker)
        viewModePicker.buttons.element(boundBy: 1).tap() // List/Table mode
        XCTAssertTrue(app.staticTexts["HP5 Plus"].exists)
        viewModePicker.buttons.element(boundBy: 0).tap() // Back to Cards mode
        XCTAssertTrue(app.staticTexts["Ilford HP5 Plus"].exists)

        // Search bar filtering
        let searchField = app.searchFields["Search films..."]
        if !searchField.exists {
            app.swipeDown()
        }
        waitFor(searchField)
        searchField.tap()
        searchField.typeText("Ektar")
        XCTAssertTrue(app.staticTexts["Kodak Ektar 100"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.staticTexts["Ilford HP5 Plus"].exists)

        // Cancel / close search (iOS 26/27 Liquid Glass uses "Close", older iOS uses "Cancel")
        if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else if app.buttons["Clear text"].exists {
            app.buttons["Clear text"].tap()
            searchField.typeText("\n")
        }
        waitFor(app.staticTexts["Ilford HP5 Plus"])

        // Filter popover: Expired only -> Reset -> Group by ISO
        let filterBtn = app.buttons["browse.filterButton"]
        filterBtn.tap()
        waitFor(app.navigationBars["Filter"])

        app.buttons["EXPIRED"].tap()
        app.navigationBars["Filter"].buttons["Done"].tap()

        waitFor(app.staticTexts["Ilford HP5 Plus"])
        XCTAssertFalse(app.staticTexts["Kodak Ektar 100"].exists)

        // Re-open Filter, tap Reset, set Group by -> ISO
        filterBtn.tap()
        waitFor(app.navigationBars["Filter"])
        app.navigationBars["Filter"].buttons["Reset"].tap()

        let groupByPicker = app.buttons["filter.groupByPicker"]
        scrollToAndTap(groupByPicker, in: app)
        if app.buttons["Manufacturer"].waitForExistence(timeout: 3) {
            app.buttons["Manufacturer"].firstMatch.tap()
        }
        app.navigationBars["Filter"].buttons["Done"].tap()

        // Verify both films and Manufacturer group headers appear (headers expose as otherElements/staticTexts on iOS 27)
        waitFor(app.descendants(matching: .any)["Ilford"].firstMatch)
        waitFor(app.descendants(matching: .any)["Kodak"].firstMatch)
        XCTAssertTrue(app.staticTexts["Kodak Ektar 100"].exists)
        XCTAssertTrue(app.staticTexts["Ilford HP5 Plus"].exists)
    }

    // MARK: - 4. Cameras, Load Film, Protection Alerts, Loaded Details & Finished Rolls Lifecycle

    func testCamerasLoadFilmLoadedDetailsFinishedWorkflowAndProtectionRules() throws {
        let app = makeApp()
        app.launch()

        // Add 2 rolls of Ilford HP5 Plus with initial comment
        quickAddFilm(
            in: app,
            manufacturer: "Ilford",
            name: "HP5 Plus",
            extraRolls: 1,
            comment: "Street roll"
        )
        waitFor(app.staticTexts["2 rolls"])

        // Switch to Tab 1: Loaded Films -> Help alert & Manage Cameras
        app.tabBars.buttons["Loaded Films"].tap()
        waitFor(app.staticTexts["No Loaded Films"])

        app.buttons["loaded.helpButton"].tap()
        let helpAlert = app.alerts["Loaded Films"]
        waitFor(helpAlert)
        helpAlert.buttons["Done"].tap()

        // Manage Cameras: Add Camera + Edit Camera
        app.buttons["loaded.manageCamerasButton"].tap()
        waitFor(app.navigationBars["Manage Cameras"])
        XCTAssertTrue(app.staticTexts["No cameras yet"].exists)

        app.buttons["manageCameras.addButton"].tap()
        waitFor(app.navigationBars["Add Camera"])
        let camNameField = app.textFields["Camera Name"]
        camNameField.tap()
        camNameField.typeText("Leica M6")

        app.buttons.matching(NSPredicate(format: "label CONTAINS 'Format'")).firstMatch.tap()
        waitFor(app.navigationBars["Format"])
        app.buttons["35mm"].firstMatch.tap()
        app.navigationBars["Format"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Add Camera"])
        app.navigationBars["Add Camera"].buttons["Add"].tap()

        // Edit camera name to "Leica M6 TTL"
        waitFor(app.staticTexts["Leica M6"])
        app.staticTexts["Leica M6"].tap()
        waitFor(app.navigationBars["Edit Camera"])
        let editCamField = app.textFields["Camera Name"]
        editCamField.tap()
        editCamField.typeText(" TTL")
        app.navigationBars["Edit Camera"].buttons["Save"].tap()
        waitFor(app.staticTexts["Leica M6 TTL"])
        app.navigationBars["Manage Cameras"].buttons["Done"].tap()

        // Switch to My Films -> Film Detail -> Load Film (custom ISO 800)
        app.tabBars.buttons["My Films"].tap()
        app.staticTexts["Ilford HP5 Plus"].firstMatch.tap()
        let loadFilmBottomBtn = app.buttons["Load Film"]
        waitFor(loadFilmBottomBtn)
        loadFilmBottomBtn.tap()

        waitFor(app.navigationBars["Load Film"])
        // Leica M6 TTL is auto-selected because its 35mm format matches!
        XCTAssertTrue(app.staticTexts["Leica M6 TTL"].exists)

        let isoField = app.textFields["loadFilm.shotAtISOField"]
        waitFor(isoField)
        // Tap trailing side of right-aligned TextField so cursor sits after "400", then backspace 4x
        isoField.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        isoField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))
        isoField.typeText("800")
        waitFor(app.staticTexts["Different from film's native ISO"])

        app.navigationBars["Load Film"].buttons["Load"].tap()

        // Detail view auto-pops to My Films, leaving 1 roll in stock
        waitFor(app.navigationBars["My Films"])
        waitFor(app.staticTexts["1 roll"])

        // Protection Rule 1: Cannot delete film while loaded in camera
        let filmCell = app.cells.firstMatch
        filmCell.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
            let cannotDeleteFilmAlert = app.alerts["Cannot Remove Film"]
            waitFor(cannotDeleteFilmAlert)
            cannotDeleteFilmAlert.buttons["OK"].tap()
        }

        // Switch to Loaded Films tab
        app.tabBars.buttons["Loaded Films"].tap()
        waitFor(app.staticTexts["Ilford HP5 Plus"])
        XCTAssertTrue(app.staticTexts["ISO 800"].exists)

        // Protection Rule 2: Cannot delete camera while it has a loaded film
        app.buttons["loaded.manageCamerasButton"].tap()
        waitFor(app.staticTexts["Leica M6 TTL"])
        app.cells.firstMatch.swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
            let camAlert = app.alerts["Cannot Delete Camera"]
            waitFor(camAlert)
            camAlert.buttons["OK"].tap()
        }
        app.navigationBars["Manage Cameras"].buttons["Done"].tap()

        // Tap loaded row -> Roll Details sheet -> expand sheet, verify ISO 800 & update comment
        app.staticTexts["Ilford HP5 Plus"].firstMatch.tap()
        waitFor(app.navigationBars["Roll Details"])
        XCTAssertTrue(app.staticTexts["Leica M6 TTL"].exists)

        // Scroll inside the sheet's List so Film & Comments sections materialize in the half-sheet
        let rollDetailsList = app.collectionViews.firstMatch
        if rollDetailsList.exists {
            rollDetailsList.swipeUp()
        }
        waitFor(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'ISO 800'")).firstMatch)

        if rollDetailsList.exists {
            rollDetailsList.swipeUp()
        }
        let loadedCommentField = app.textViews.firstMatch.exists
            ? app.textViews.firstMatch
            : app.textFields["Add a note about this roll…"]
        if loadedCommentField.waitForExistence(timeout: 3) {
            loadedCommentField.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
            loadedCommentField.typeText(" +1")
        }
        app.navigationBars["Roll Details"].buttons["Done"].tap()

        // Swipe loaded row -> Change Date
        let loadedCell = app.cells.firstMatch
        loadedCell.swipeLeft()
        waitFor(app.buttons["Change Date"])
        app.buttons["Change Date"].tap()
        waitFor(app.navigationBars["Change Loaded Date"])
        app.navigationBars["Change Loaded Date"].buttons["Save"].tap()

        // Swipe loaded row -> Finish Roll
        loadedCell.swipeLeft()
        waitFor(app.buttons["Finish Roll"])
        app.buttons["Finish Roll"].tap()
        waitFor(app.staticTexts["No Loaded Films"])

        // Switch segment to "Finished Rolls"
        app.segmentedControls.buttons["Finished Rolls"].tap()
        waitFor(app.staticTexts["Ilford HP5 Plus"])
        XCTAssertTrue(app.staticTexts["To develop"].exists)

        // Tap finished row -> Finished Roll detail sheet + Edit finished date + verify comment carried over
        app.staticTexts["Ilford HP5 Plus"].firstMatch.tap()
        waitFor(app.navigationBars["Finished Roll"])
        let editFinDateBtn = app.buttons["Edit finished date"]
        waitFor(editFinDateBtn)
        editFinDateBtn.tap()
        waitFor(app.navigationBars["Change finished date"])
        app.navigationBars["Change finished date"].buttons["Save"].tap()

        let finishedDetailList = app.collectionViews.firstMatch
        if finishedDetailList.exists {
            finishedDetailList.swipeUp()
        }
        waitFor(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Street roll'")).firstMatch)
        app.navigationBars["Finished Roll"].buttons["Done"].tap()

        // Status transitions via swipe: To develop -> In development -> Developed
        let finishedCell = app.cells.firstMatch
        finishedCell.swipeLeft()
        waitFor(app.buttons["In development"])
        app.buttons["In development"].tap()
        waitFor(app.staticTexts["In development"])

        finishedCell.swipeLeft()
        waitFor(app.buttons["Developed"])
        app.buttons["Developed"].tap()
        waitFor(app.staticTexts["Developed"])

        // Finished Rolls filter sheet
        app.buttons["finished.filterButton"].tap()
        waitFor(app.navigationBars["Filter"])
        let devToggle = app.switches["Developed"]
        if devToggle.waitForExistence(timeout: 2) {
            devToggle.tap()
        }
        app.navigationBars["Filter"].buttons["Done"].tap()
        waitFor(app.staticTexts["Ilford HP5 Plus"])

        // Re-load finished roll back to Loaded, then Remove (cancel accidental load) to restore stock
        finishedCell.swipeLeft()
        waitFor(app.buttons["Re-load"])
        app.buttons["Re-load"].tap()
        waitFor(app.staticTexts["No Finished Rolls"])

        app.segmentedControls.buttons["Loaded"].tap()
        waitFor(app.staticTexts["Ilford HP5 Plus"])
        app.cells.firstMatch.swipeLeft()
        waitFor(app.buttons["Remove"])
        app.buttons["Remove"].tap()
        waitFor(app.staticTexts["No Loaded Films"])

        // Verify roll returned to My Films inventory (back to 2 rolls)
        app.tabBars.buttons["My Films"].tap()
        waitFor(app.staticTexts["2 rolls"])
    }

    // MARK: - 5. My Collection Custom Reminder Cards Gallery, Detail Pager & Multi-Delete

    func testMyCollectionGalleryDetailAndMultiSelectDelete() throws {
        let app = makeApp(extraArgs: ["-UITestSeedCustomPhotos"])
        app.launch()

        app.tabBars.buttons["My Collection"].tap()
        waitFor(app.navigationBars["My Collection"])

        // Help dialog
        app.buttons["collection.helpButton"].tap()
        let helpAlert = app.alerts["My Collection"]
        waitFor(helpAlert)
        helpAlert.buttons["Done"].tap()

        // Tap first thumbnail -> opens ImageDetailView ("1 of 2")
        let thumb0 = app.buttons["collection.thumbnail.0"]
        waitFor(thumb0)
        thumb0.tap()
        waitFor(app.navigationBars["1 of 2"])
        app.navigationBars["1 of 2"].buttons["Done"].tap()

        // Multi-select Edit mode -> select both -> delete -> verify empty state
        let editBtn = app.navigationBars["My Collection"].buttons["Edit"]
        waitFor(editBtn)
        editBtn.tap()

        thumb0.tap()
        let thumb1 = app.buttons["collection.thumbnail.1"]
        waitFor(thumb1)
        thumb1.tap()

        let deleteSelectedBtn = app.buttons["collection.deleteSelectedButton"]
        waitFor(deleteSelectedBtn)
        deleteSelectedBtn.tap()

        let deleteAlert = app.alerts["Delete Image"]
        waitFor(deleteAlert)
        deleteAlert.buttons["Delete"].tap()

        waitFor(app.staticTexts["No film reminder cards (yet)"])
    }

    // MARK: - 6. Settings, Custom Formats, Fridge Mode, Statistics, Appearance, Export/Import, About & Support

    func testSettingsFormatsFridgeStatisticsExportAboutAndSupport() throws {
        let app = makeApp()
        app.launch()

        // Add 1 roll so Statistics & Export reflect populated inventory
        quickAddFilm(in: app, manufacturer: "Kodak", name: "Gold 200")
        waitFor(app.staticTexts["1 roll"])

        // Open Settings
        app.buttons["browse.settingsButton"].tap()
        waitFor(app.navigationBars["Settings"])

        // Enable Fridge flag & Show expiry date in chip
        let fridgeSwitch = app.switches["Enable Fridge flag"]
        toggleSwitch(fridgeSwitch)

        let expiryChipSwitch = app.switches["Show expiry date in chip"]
        if expiryChipSwitch.exists {
            toggleSwitch(expiryChipSwitch)
        }

        // Manage Formats: add & delete a custom format
        let filmFormatsRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Film Formats'")).firstMatch
        scrollToAndTap(filmFormatsRow, in: app)
        waitFor(app.navigationBars["Manage Formats"])

        scrollToAndTap(app.buttons["Add Custom Format"], in: app)
        let formatAlert = app.alerts["Add Format"]
        waitFor(formatAlert)
        let formatField = formatAlert.textFields.firstMatch
        formatField.tap()
        formatField.typeText("65mm XPan")
        formatAlert.buttons["Add"].tap()

        waitFor(app.staticTexts["65mm XPan"])
        app.staticTexts["65mm XPan"].swipeLeft()
        if app.buttons["Delete"].waitForExistence(timeout: 2) {
            app.buttons["Delete"].tap()
        }
        app.navigationBars["Manage Formats"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Settings"])

        // Statistics screen (verifying Fridge Films row appears when Fridge flag is ON)
        scrollToAndTap(app.staticTexts["Statistics"], in: app)
        waitFor(app.navigationBars["Statistics"])
        XCTAssertTrue(app.staticTexts["Total Rolls"].exists)
        XCTAssertTrue(app.staticTexts["Unique Films"].exists)
        XCTAssertTrue(app.staticTexts["Fridge Films"].exists)
        app.navigationBars["Statistics"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Settings"])

        // Appearance screen
        scrollToAndTap(app.staticTexts["Appearance"], in: app)
        waitFor(app.navigationBars["Appearance"])
        app.buttons["Dark"].firstMatch.tap()
        app.buttons["Light"].firstMatch.tap()
        app.buttons["System"].firstMatch.tap()
        app.navigationBars["Appearance"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Settings"])

        // Export or Import Inventory screen
        scrollToAndTap(app.staticTexts["Export or Import Inventory"], in: app)
        waitFor(app.navigationBars["Export"])
        XCTAssertTrue(app.staticTexts["Film inventory"].exists)
        app.staticTexts["CSV"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Export & Share"].exists)

        // Switch to Import segment
        app.segmentedControls.buttons["Import"].tap()
        waitFor(app.buttons["Choose File"])
        XCTAssertTrue(app.staticTexts["JSON (FilmStock export)"].exists)
        app.navigationBars["Export"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Settings"])

        // About, Privacy Policy & Terms of Service
        scrollToAndTap(app.staticTexts["About"], in: app)
        waitFor(app.navigationBars["About"])
        XCTAssertTrue(app.staticTexts["Your Personal Film Collection Manager"].exists)

        scrollToAndTap(app.buttons["Privacy Policy"], in: app)
        waitFor(app.navigationBars["Privacy Policy"])
        app.navigationBars["Privacy Policy"].buttons.firstMatch.tap()

        waitFor(app.navigationBars["About"])
        scrollToAndTap(app.buttons["Terms of Service"], in: app)
        waitFor(app.navigationBars["Terms of Service"])
        app.navigationBars["Terms of Service"].buttons.firstMatch.tap()

        waitFor(app.navigationBars["About"])
        app.navigationBars["About"].buttons.firstMatch.tap()
        waitFor(app.navigationBars["Settings"])

        // Manual What's New presentation from Settings
        scrollToAndTap(app.buttons["What's New"], in: app)
        waitFor(app.staticTexts["Comments on Loaded Films"])
        app.buttons["Continue"].tap()
        waitFor(app.navigationBars["Settings"])

        // Support / Buy Me a Coffee screen
        scrollToAndTap(app.staticTexts["Buy Me a Coffee"], in: app)
        waitFor(app.navigationBars["Support"])
        XCTAssertTrue(app.staticTexts["Support FilmStock"].exists)
        XCTAssertTrue(app.buttons["Restore Purchases"].exists)
        app.navigationBars["Support"].buttons.firstMatch.tap()

        waitFor(app.navigationBars["Settings"])
        app.navigationBars["Settings"].buttons["Done"].tap()
        waitFor(app.navigationBars["My Films"])
    }
}

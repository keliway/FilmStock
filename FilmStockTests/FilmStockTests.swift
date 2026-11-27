//
//  FilmStockTests.swift
//  FilmStockTests
//
//  Comprehensive end-to-end unit & integration test suite for Analog FilmStock.
//

import Foundation
import SwiftData
import Testing
import UIKit
@testable import Analog_FilmStock

@Suite("Analog FilmStock Full Feature Unit & Integration Suite", .serialized)
@MainActor
struct FilmStockTests {

    // MARK: - Test Environment Helpers

    private func makeIsolatedEnvironment() throws -> (ModelContainer, ModelContext, FilmStockDataManager) {
        SettingsManager.shared.resetToDefaults()
        OnboardingManager.shared.resetOnboarding()
        UserDefaults.standard.removeObject(forKey: "stats_finishedFilmsCount")
        UserDefaults.standard.set(true, forKey: "migration_rollCentric_v1")

        let schema = Schema([
            Manufacturer.self,
            Film.self,
            MyFilm.self,
            Camera.self,
            LoadedFilm.self,
            FinishedFilm.self
        ])
        let config = ModelConfiguration(
            "TestStore_\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        let manager = FilmStockDataManager()
        manager.setModelContext(context)
        return (container, context, manager)
    }

    // MARK: - 1. Models, Formats, Exposures & Date Parsing

    @Test("FilmStock model enforces storage mutual exclusion and format metadata")
    func filmStockModelAndFormats() throws {
        let stock = FilmStock(
            id: UUID().uuidString,
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .thirtyFive,
            quantity: 2,
            expireDate: ["122028"],
            comments: "Push +1",
            isFrozen: true,
            isFridge: true, // Should normalize to false when frozen is true
            exposures: 36
        )
        #expect(stock.isFrozen == true)
        #expect(stock.isFridge == false)
        #expect(stock.formatDisplayName == "35mm")
        #expect(FilmStock.FilmFormat.thirtyFive.isRollFormat == true)
        #expect(FilmStock.FilmFormat.thirtyFive.isSheetFormat == false)
        #expect(FilmStock.FilmFormat.thirtyFive.defaultExposures == 36)
        #expect(FilmStock.FilmFormat.fourByFive.isSheetFormat == true)
        #expect(FilmStock.FilmFormat.fourByFive.isRollFormat == false)
        #expect(FilmStock.FilmFormat.fourByFive.quantityUnit == "Sheets")

        let customFormatStock = FilmStock(
            id: UUID().uuidString,
            name: "Aerochrome",
            manufacturer: "Kodak",
            type: .slide,
            filmSpeed: 400,
            format: .other,
            customFormatName: "70mm",
            quantity: 1,
            exposures: kBulkRollExposures
        )
        #expect(customFormatStock.formatDisplayName == "70mm")
        #expect(exposureDisplayLabel(kBulkRollExposures) == "100ft bulk")
        #expect(exposureShortLabel(kBulkRollExposures) == "100ft bulk")
        #expect(exposureShortLabel(36) == "36 exp")

        // Verify custom Codable decoder also enforces frozen/fridge exclusion and null expireDate
        let json = """
        {
            "id": "test-1",
            "name": "Portra 400",
            "manufacturer": "Kodak",
            "type": "Color",
            "filmSpeed": 400,
            "format": "120",
            "quantity": 1,
            "expireDate": null,
            "isFrozen": true,
            "isFridge": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(FilmStock.self, from: json)
        #expect(decoded.isFrozen == true)
        #expect(decoded.isFridge == false)
        #expect(decoded.expireDate == nil)
    }

    @Test("Expiry date parsing, formatting, and form validation cover all formats and edge cases")
    func expiryDateParsingAndValidation() {
        let cal = Calendar.current

        // YYYY -> Dec 31 of that year
        let yearOnly = FilmStock.parseExpireDate("2028")
        #expect(yearOnly != nil)
        if let yearOnly {
            #expect(cal.component(.year, from: yearOnly) == 2028)
            #expect(cal.component(.month, from: yearOnly) == 12)
            #expect(cal.component(.day, from: yearOnly) == 31)
        }

        // MMYYYY -> end of month (leap year Feb 2028 -> 29)
        let febLeap = FilmStock.parseExpireDate("022028")
        #expect(febLeap != nil)
        if let febLeap {
            #expect(cal.component(.month, from: febLeap) == 2)
            #expect(cal.component(.day, from: febLeap) == 29)
        }

        // Slash & ISO formats
        #expect(FilmStock.parseExpireDate("09/2027") != nil)
        #expect(FilmStock.parseExpireDate("9/2027") != nil)
        #expect(FilmStock.parseExpireDate("09/27") != nil)
        #expect(FilmStock.parseExpireDate("2027-09") != nil)
        #expect(FilmStock.parseExpireDate("2027-09-15") != nil)

        // Invalid dates rejected
        #expect(FilmStock.parseExpireDate("132027") == nil)
        #expect(FilmStock.parseExpireDate("2025-02-29") == nil)
        #expect(FilmStock.parseExpireDate("abc") == nil)

        // Display formatting
        #expect(FilmStock.formatExpireDate("062028") == "06/2028")
        #expect(FilmStock.formatExpireDate("6/2028") == "06/2028")
        #expect(FilmStock.formatExpireDate("2028") == "2028")

        // Form input auto-formatter & validator
        #expect(FilmStock.formatExpiryInput("082029") == "08/2029")
        #expect(FilmStock.formatExpiryInput("2029") == "2029")
        #expect(FilmStock.validateExpiryInput("") == nil)
        #expect(FilmStock.validateExpiryInput("2028") == nil)
        #expect(FilmStock.validateExpiryInput("08/2028") == nil)
        #expect(FilmStock.validateExpiryInput("13/2028") != nil)
        #expect(FilmStock.validateExpiryInput("1940") != nil)
        #expect(FilmStock.validateExpiryInput("123") != nil)
    }

    // MARK: - 2. Inventory CRUD, Roll Splitting, Sheet Merging & Collision Merge

    @Test("Adding roll vs sheet vs custom-format inventory splits rolls and merges matching sheet lines")
    func inventoryRollSplittingAndSheetMerging() throws {
        let (container, _, manager) = try makeIsolatedEnvironment()
        _ = container // keep alive

        // 1. Add 3 rolls of 35mm Ilford HP5 Plus -> creates 3 individual MyFilm(quantity: 1) records
        let hp5 = FilmStock(
            id: UUID().uuidString,
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .thirtyFive,
            quantity: 3,
            expireDate: ["102028"],
            comments: "Studio batch",
            isFrozen: true,
            exposures: 36
        )
        let existedFirst = manager.addFilmStock(hp5)
        #expect(existedFirst == false)
        #expect(manager.filmStocks.count == 3)
        #expect(manager.filmStocks.allSatisfy { $0.quantity == 1 && $0.isFrozen })

        let grouped = try #require(manager.cachedGroupedFilms.first)
        #expect(grouped.formats.count == 1)
        #expect(grouped.formats[0].quantity == 3)
        #expect(grouped.formats[0].frozenCount == 3)
        #expect(grouped.formats[0].rollIds.count == 3)

        // 2. Add 10 sheets of 4x5 HP5 Plus twice with identical storage & expiry -> merges into 1 MyFilm(quantity: 20)
        let sheets1 = FilmStock(
            id: UUID().uuidString,
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .fourByFive,
            quantity: 10,
            expireDate: ["122029"],
            isFrozen: false,
            isFridge: true
        )
        let existedSecond = manager.addFilmStock(sheets1)
        #expect(existedSecond == true)

        let sheets2 = FilmStock(
            id: UUID().uuidString,
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .fourByFive,
            quantity: 15,
            expireDate: ["12/2029"], // Normalized digits match "122029"
            isFrozen: false,
            isFridge: true
        )
        manager.addFilmStock(sheets2)

        let sheetStocks = manager.filmStocks.filter { $0.format == .fourByFive }
        #expect(sheetStocks.count == 1)
        #expect(sheetStocks[0].quantity == 25)

        // 3. Add 4x5 sheets with DIFFERENT storage (frozen) -> stays a separate inventory line
        let frozenSheets = FilmStock(
            id: UUID().uuidString,
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .fourByFive,
            quantity: 5,
            expireDate: ["122029"],
            isFrozen: true
        )
        manager.addFilmStock(frozenSheets)
        #expect(manager.filmStocks.filter { $0.format == .fourByFive }.count == 2)
    }

    @Test("Roll batch operations (addRolls, updateRolls, deleteRollsById) and Film collision merging")
    func rollMutationsAndCollisionMerge() throws {
        let (container, _, manager) = try makeIsolatedEnvironment()
        _ = container

        let portra = FilmStock(
            id: UUID().uuidString,
            name: "Portra 400",
            manufacturer: "Kodak",
            type: .color,
            filmSpeed: 400,
            format: .thirtyFive,
            quantity: 2,
            expireDate: ["052028"],
            exposures: 36
        )
        manager.addFilmStock(portra)

        let refId = try #require(manager.filmStocks.first?.id)
        let added = manager.addRolls(
            count: 2,
            matchingFilmStockId: refId,
            expireDate: "012020", // Expired
            isFrozen: false,
            isFridge: true,
            exposures: 24,
            comments: "Expired test rolls"
        )
        #expect(added == true)
        #expect(manager.filmStocks.count == 4)

        // Update the first roll
        manager.updateRolls(
            ids: [refId],
            expireDate: "092030",
            isFrozen: true,
            isFridge: true,
            exposures: kBulkRollExposures,
            comments: "Bulk loader"
        )
        let updated = try #require(manager.filmStocks.first { $0.id == refId })
        #expect(updated.isFrozen == true)
        #expect(updated.isFridge == false)
        #expect(updated.exposures == kBulkRollExposures)
        #expect(updated.comments == "Bulk loader")

        // Delete 1 roll by ID
        manager.deleteRollsById([refId])
        #expect(manager.filmStocks.count == 3)

        // Create a second distinct film ("Portra 400 Typo"), then edit its metadata to collide with "Portra 400"
        let typoStock = FilmStock(
            id: UUID().uuidString,
            name: "Portra 400 Typo",
            manufacturer: "Kodak",
            type: .color,
            filmSpeed: 400,
            format: .oneTwenty,
            quantity: 2
        )
        manager.addFilmStock(typoStock)
        #expect(manager.cachedGroupedFilms.count == 2)

        let typoGroup = try #require(manager.cachedGroupedFilms.first { $0.name == "Portra 400 Typo" })
        manager.updateFilmInfo(
            groupedFilm: typoGroup,
            name: "Portra 400",
            manufacturer: "Kodak",
            type: .color,
            filmSpeed: 400,
            imageName: nil,
            imageSource: ImageSource.autoDetected.rawValue
        )

        // Both 35mm and 120 rolls should now live under a single "Portra 400" GroupedFilm without duplicates
        #expect(manager.cachedGroupedFilms.count == 1)
        let mergedGroup = try #require(manager.cachedGroupedFilms.first)
        #expect(mergedGroup.formats.map(\.quantity).reduce(0, +) == 5)
    }

    // MARK: - 3. Roll-Centric Migration & Database Self-Healing

    @Test("Legacy multi-quantity roll migration and self-healing integrity repair work end-to-end")
    func legacyMigrationAndIntegrityRepair() async throws {
        let (container, context, manager) = try makeIsolatedEnvironment()
        _ = container
        UserDefaults.standard.set(false, forKey: "migration_rollCentric_v1")

        let mfr = Manufacturer(name: "Fujifilm", isCustom: false)
        context.insert(mfr)
        let film = Film(name: "Velvia 50", manufacturer: mfr, type: FilmStock.FilmType.slide.rawValue, filmSpeed: 50)
        context.insert(film)

        // Insert legacy MyFilm with quantity = 3 on a roll format
        let legacyRoll = MyFilm(
            id: "legacy-velvia",
            format: FilmStock.FilmFormat.oneTwenty.rawValue,
            quantity: 3,
            expireDate: ["042027", "082027"],
            comments: "Landscape",
            isFrozen: true,
            film: film
        )
        context.insert(legacyRoll)

        // Insert FinishedFilm with empty ID and live Camera link to verify self-healing decoupling
        let cam = Camera(name: "Hasselblad 500C/M", format: "120")
        context.insert(cam)
        let finished = FinishedFilm(
            id: "",
            film: nil, // Missing film link, should restore from legacyRoll
            format: "120",
            camera: cam,
            myFilm: legacyRoll,
            quantity: 1,
            loadedAt: Date().addingTimeInterval(-86400),
            finishedAt: Date()
        )
        context.insert(finished)
        try context.save()

        await manager.migrateIfNeeded()

        #expect(manager.isMigrationComplete == true)
        // 3 individual rolls created from legacy quantity 3
        let velviaRolls = manager.filmStocks.filter { $0.name == "Velvia 50" }
        #expect(velviaRolls.count == 3)
        #expect(velviaRolls.allSatisfy { $0.quantity == 1 })

        // Verify FinishedFilm was repaired: non-empty ID, camera decoupled into cameraName, film restored, comments backfilled
        let repairedFinished = try #require(manager.getFinishedFilms().first)
        #expect(!repairedFinished.id.isEmpty)
        #expect(repairedFinished.camera == nil)
        #expect(repairedFinished.cameraName == "Hasselblad 500C/M")
        #expect(repairedFinished.film?.name == "Velvia 50")
        #expect(repairedFinished.effectiveComments == "Landscape")
    }

    // MARK: - 4. Manufacturers, Cameras & Protection Rules

    @Test("Custom manufacturers and cameras enforce duplicate and in-use deletion rules")
    func manufacturersAndCamerasRules() throws {
        let (container, context, manager) = try makeIsolatedEnvironment()
        _ = container

        // Built-in manufacturer cannot be deleted
        let builtIn = Manufacturer(name: "Kodak", isCustom: false)
        context.insert(builtIn)
        try context.save()
        #expect(manager.deleteManufacturer(builtIn) == false)

        // Custom manufacturer can be added, blocked while referenced by a Film, and deleted once unused
        let customMfr = manager.addManufacturer(name: "Silbersalz35")
        #expect(customMfr.isCustom == true)

        let customFilm = FilmStock(
            id: UUID().uuidString,
            name: "250D",
            manufacturer: "Silbersalz35",
            type: .color,
            filmSpeed: 250,
            format: .thirtyFive,
            quantity: 1
        )
        manager.addFilmStock(customFilm)
        #expect(manager.deleteManufacturer(customMfr) == false)

        // Load into a camera -> neither grouped film nor camera may be deleted while loaded!
        let cam = manager.addCamera(name: "Leica M6", format: "35")
        let duplicateCam = manager.addCamera(name: "Leica M6", format: "120")
        #expect(cam.persistentModelID == duplicateCam.persistentModelID)

        let rollId = try #require(manager.filmStocks.first?.id)
        #expect(manager.loadFilm(filmStockId: rollId, format: .thirtyFive, cameraName: "Leica M6", shotAtISO: 400) == true)

        let group = try #require(manager.cachedGroupedFilms.first { $0.manufacturer == "Silbersalz35" })
        #expect(manager.isGroupedFilmLoaded(group) == true)
        #expect(manager.deleteGroupedFilm(group) != nil) // Returns error message
        #expect(manager.deleteCamera(cam) == false)

        // Unload film -> camera can now be deleted while FinishedFilm keeps cameraName snapshot!
        let loaded = try #require(manager.getLoadedFilms().first)
        manager.unloadFilm(loaded)
        #expect(manager.deleteCamera(cam) == true)

        let finished = try #require(manager.getFinishedFilms().first)
        #expect(finished.cameraName == "Leica M6")
    }

    // MARK: - 5. Loaded & Finished Film Workflow (Rolls & Partial Sheets)

    @Test("Full lifecycle: load, edit date & comments, accidental-load cancel, partial sheet unload, status & re-load")
    func loadedAndFinishedLifecycle() throws {
        let (container, _, manager) = try makeIsolatedEnvironment()
        _ = container

        // 1. Roll load -> cancel load (Remove) restores inventory without counting as finished
        let triX = FilmStock(
            id: UUID().uuidString,
            name: "Tri-X 400",
            manufacturer: "Kodak",
            type: .bw,
            filmSpeed: 400,
            format: .thirtyFive,
            quantity: 1,
            comments: "Street roll"
        )
        manager.addFilmStock(triX)
        let triXId = try #require(manager.filmStocks.first?.id)
        #expect(manager.loadFilm(filmStockId: triXId, format: .thirtyFive, cameraName: "Nikon FM2", shotAtISO: 400) == true)

        let loadedTriX = try #require(manager.getLoadedFilms().first)
        #expect(loadedTriX.shotAtISO == nil) // Native speed stored as nil
        #expect(loadedTriX.effectiveISO == 400)
        #expect(loadedTriX.effectiveComments == "Street roll")

        // Edit comments and loaded date
        let customLoadedDate = Date().addingTimeInterval(-3 * 86400)
        manager.updateLoadedFilmDate(loadedTriX, loadedAt: customLoadedDate)
        manager.updateLoadedFilmComments(loadedTriX, comments: "Pushed to 1600 at night")
        #expect(loadedTriX.effectiveComments == "Pushed to 1600 at night")

        // Cancel load -> restores inventory roll to quantity 1, 0 finished rolls
        manager.deleteLoadedFilm(loadedTriX)
        #expect(manager.getLoadedFilms().isEmpty)
        #expect(manager.getFinishedFilms().isEmpty)
        #expect(manager.filmStocks.first(where: { $0.id == triXId })?.quantity == 1)
        #expect(manager.filmStocks.first(where: { $0.id == triXId })?.comments == "Pushed to 1600 at night")

        // 2. Sheet film partial unload -> finish -> status transitions -> re-load
        let ektarSheets = FilmStock(
            id: UUID().uuidString,
            name: "Ektar 100",
            manufacturer: "Kodak",
            type: .color,
            filmSpeed: 100,
            format: .fourByFive,
            quantity: 4
        )
        manager.addFilmStock(ektarSheets)
        let sheetStockId = try #require(manager.filmStocks.first { $0.format == .fourByFive }?.id)
        #expect(manager.loadFilm(filmStockId: sheetStockId, format: .fourByFive, cameraName: "Intrepid 4x5", quantity: 3, shotAtISO: 80) == true)
        #expect(manager.filmStocks.first { $0.id == sheetStockId }?.quantity == 1) // 4 - 3 = 1 remaining in box

        let loadedSheets = try #require(manager.getLoadedFilms().first)
        #expect(loadedSheets.quantity == 3)
        #expect(loadedSheets.effectiveISO == 80)

        // Unload 1 sheet -> 2 remain loaded, 1 finished
        manager.unloadFilm(loadedSheets, quantity: 1)
        #expect(manager.getLoadedFilms().first?.quantity == 2)
        #expect(manager.getFinishedFilms().count == 1)
        #expect(manager.getFinishedFilmsCount() == 1)

        // Finish remaining 2 sheets
        manager.unloadFilm(loadedSheets)
        #expect(manager.getLoadedFilms().isEmpty)
        #expect(manager.getFinishedFilms().count == 2)
        #expect(manager.getFinishedFilmsCount() == 3)

        // Status transitions on finished roll
        let finishedItem = try #require(manager.getFinishedFilms().first)
        manager.updateFinishedFilmStatus(finishedItem, status: .inDevelopment)
        #expect(finishedItem.status == FinishedFilmStatus.inDevelopment.rawValue)
        #expect(finishedItem.developedAt == nil)

        manager.updateFinishedFilmStatus(finishedItem, status: .developed)
        #expect(finishedItem.status == FinishedFilmStatus.developed.rawValue)
        #expect(finishedItem.developedAt != nil)

        let editedFinishDate = Date().addingTimeInterval(-3600)
        manager.updateFinishedFilmFinishedAt(finishedItem, finishedAt: editedFinishDate)
        #expect(abs(finishedItem.finishedAt.timeIntervalSince(editedFinishDate)) < 1.0)

        // Re-load finished item back to Loaded
        let qtyReloaded = finishedItem.quantity
        manager.reloadFinishedFilm(finishedItem)
        #expect(manager.getLoadedFilms().count == 1)
        #expect(manager.getFinishedFilms().count == 1)
        #expect(manager.getFinishedFilmsCount() == 3 - qtyReloaded)
    }

    // MARK: - 6. Settings, Custom Formats, Catalog, DX & Custom Images

    @Test("SettingsManager, OnboardingManager, ImageStorage catalog, DX codes & custom photo lifecycle")
    func settingsOnboardingAndImageStorage() throws {
        let (container, _, manager) = try makeIsolatedEnvironment()
        _ = container

        // SettingsManager Fridge & Custom Format canonicalization
        let settings = SettingsManager.shared
        settings.enableFridge = true
        settings.filterShowFridgeOnly = true
        settings.enableFridge = false
        #expect(settings.filterShowFridgeOnly == false) // Automatically cleared when Fridge disabled

        #expect(settings.canonicalCustomFormat("  Half Frame  ") == "Half Frame")
        #expect(settings.isCustomFormat("half frame") == true)
        #expect(settings.isFormatEnabled("Half Frame") == true)
        // Built-in format is NOT duplicated as custom format
        #expect(settings.canonicalCustomFormat("35mm") == "35mm")
        #expect(settings.customFormats == ["Half Frame"])
        settings.deleteCustomFormat("HALF FRAME")
        #expect(settings.customFormats.isEmpty)

        // OnboardingManager
        OnboardingManager.shared.hasCompletedOnboarding = true
        OnboardingManager.shared.markTooltipSeen("addFilm")
        #expect(OnboardingManager.shared.hasSeenTooltip("addFilm") == true)
        OnboardingManager.shared.resetOnboarding()
        #expect(OnboardingManager.shared.hasCompletedOnboarding == false)
        #expect(OnboardingManager.shared.hasSeenTooltip("addFilm") == false)

        // ImageStorage catalog metadata & DX barcode decoding
        let metadata = ImageStorage.shared.detectFilmMetadata(filmName: "Portra 400", manufacturer: "Kodak")
        #expect(metadata.filmSpeed == 400)
        #expect(metadata.hasImage == true)
        #expect(ImageStorage.shared.loadDefaultImage(filmName: "Portra 400", manufacturer: "Kodak") != nil)

        // DX exposure decoding (ANSI IT1.14 last digit: 3 -> 24, 4 -> 36, 1 -> 12)
        #expect(ImageStorage.shared.exposures(fromScannedDXCode: "017713") == 24)
        #expect(ImageStorage.shared.exposures(fromScannedDXCode: "017714") == 36)
        #expect(ImageStorage.shared.exposures(fromScannedDXCode: "017711") == 12)

        let manufacturers = ImageStorage.shared.loadManufacturersData()
        #expect(!manufacturers.isEmpty)
        if let sampleDX = manufacturers.flatMap(\.films).flatMap(\.dx).first(where: { $0 != "000000" }) {
            #expect(!ImageStorage.shared.filmsMatching(dxCode: sampleDX).isEmpty)
        }

        // Custom image save -> load -> unreferenced cleanup
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
        let testImage = renderer.image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        let savedFilename = try #require(
            ImageStorage.shared.saveImage(testImage, forManufacturer: "UnitTestMfr", filmName: "TestCard")
        )
        #expect(ImageStorage.shared.loadImage(filename: savedFilename, manufacturer: "UnitTestMfr") != nil)
        manager.deleteCustomImageIfUnreferenced(
            imageName: "UnitTestMfr/\(savedFilename)",
            defaultManufacturer: "UnitTestMfr"
        )
        #expect(ImageStorage.shared.loadImage(filename: savedFilename, manufacturer: "UnitTestMfr") == nil)
    }

    // MARK: - 7. Export & Import End-to-End Round-Trip (JSON & CSV)

    @Test("JSON and CSV Export -> Import round-trips preserve inventory, loaded, finished, cameras, comments & bulk rolls")
    func exportAndImportJSONAndCSVRoundTrip() throws {
        let (sourceContainer, sourceContext, sourceManager) = try makeIsolatedEnvironment()
        _ = sourceContainer

        // Populate rich source data:
        // 1. Camera with explicit format
        _ = sourceManager.addCamera(name: "Contax T2", format: "35")
        _ = sourceManager.addCamera(name: "Mamiya 7", format: "120")

        // 2. Bulk roll + multiline/comma/quote comment to exercise CSV RFC-4180 escaping
        let trickyComment = "Shot in Tokyo, \"Shinjuku\"\nLine 2 #notAHeader"
        let cinestill = FilmStock(
            id: UUID().uuidString,
            name: "800T",
            manufacturer: "Cinestill",
            type: .color,
            filmSpeed: 800,
            format: .thirtyFive,
            quantity: 2,
            expireDate: ["112028"],
            comments: trickyComment,
            isFrozen: true,
            exposures: kBulkRollExposures
        )
        sourceManager.addFilmStock(cinestill)

        // 3. Custom format stock
        SettingsManager.shared.addCustomFormat("Panoramic")
        let customStock = FilmStock(
            id: UUID().uuidString,
            name: "XP2 Super",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .other,
            customFormatName: "Panoramic",
            quantity: 3,
            isFridge: true
        )
        sourceManager.addFilmStock(customStock)

        // 4. Load 1 Cinestill roll into Contax T2 & finish another roll on Mamiya 7
        let rollToLoad = try #require(sourceManager.filmStocks.first { $0.name == "800T" }?.id)
        #expect(sourceManager.loadFilm(filmStockId: rollToLoad, format: .thirtyFive, cameraName: "Contax T2", shotAtISO: 1600) == true)

        let delta = FilmStock(
            id: UUID().uuidString,
            name: "Delta 100",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 100,
            format: .oneTwenty,
            quantity: 1,
            comments: "Tripod landscapes"
        )
        sourceManager.addFilmStock(delta)
        let deltaId = try #require(sourceManager.filmStocks.first { $0.name == "Delta 100" }?.id)
        #expect(sourceManager.loadFilm(filmStockId: deltaId, format: .oneTwenty, cameraName: "Mamiya 7") == true)
        let loadedDelta = try #require(sourceManager.getLoadedFilms().first { $0.cameraName == "Mamiya 7" })
        sourceManager.unloadFilm(loadedDelta)
        let finishedDelta = try #require(sourceManager.getFinishedFilms().first)
        sourceManager.updateFinishedFilmStatus(finishedDelta, status: .developed)

        // --- A. JSON Export -> Import into fresh DB ---
        let jsonURL = try ExportManager.shared.exportJSON(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let jsonParsed = try ExportManager.shared.importAll(from: jsonURL)
        #expect(!jsonParsed.isEmpty)
        #expect(jsonParsed.loadedFilms.count == 1)
        #expect(jsonParsed.finishedFilms.count == 1)
        #expect(jsonParsed.cameras.count == 2)

        let (jsonDestContainer, _, jsonDestManager) = try makeIsolatedEnvironment()
        _ = jsonDestContainer
        try jsonDestManager.importData(jsonParsed)

        #expect(jsonDestManager.getAllCameras().count == 2)
        #expect(jsonDestManager.getLoadedFilms().count == 1)
        #expect(jsonDestManager.getLoadedFilms().first?.effectiveISO == 1600)
        #expect(jsonDestManager.getFinishedFilms().count == 1)
        #expect(jsonDestManager.getFinishedFilms().first?.status == "developed")
        #expect(jsonDestManager.filmStocks.first(where: { $0.name == "800T" && $0.quantity > 0 })?.comments == trickyComment)
        #expect(jsonDestManager.filmStocks.first(where: { $0.name == "800T" && $0.quantity > 0 })?.exposures == kBulkRollExposures)

        // Re-importing loaded & finished films is idempotent (no duplicate loaded/finished rolls)
        try jsonDestManager.importData(jsonParsed)
        #expect(jsonDestManager.getLoadedFilms().count == 1)
        #expect(jsonDestManager.getFinishedFilms().count == 1)

        // --- B. CSV Export -> Import into fresh DB ---
        let csvURL = try ExportManager.shared.exportCSV(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: csvURL) }

        let csvParsed = try ExportManager.shared.importAll(from: csvURL)
        #expect(!csvParsed.isEmpty)
        #expect(csvParsed.loadedFilms.count == 1)
        #expect(csvParsed.finishedFilms.count == 1)
        #expect(csvParsed.cameras.count == 2)

        let (csvDestContainer, _, csvDestManager) = try makeIsolatedEnvironment()
        _ = csvDestContainer
        try csvDestManager.importData(csvParsed)

        #expect(csvDestManager.getAllCameras().count == 2)
        #expect(csvDestManager.getLoadedFilms().count == 1)
        #expect(csvDestManager.getFinishedFilms().count == 1)
        let importedCinestill = try #require(csvDestManager.filmStocks.first { $0.name == "800T" && $0.quantity > 0 })
        #expect(importedCinestill.comments == trickyComment)
        #expect(importedCinestill.exposures == kBulkRollExposures) // "100ft" round-tripped back to -2!

        // --- C. Unsupported & Invalid File Error Handling ---
        let badExtURL = FileManager.default.temporaryDirectory.appendingPathComponent("bad_\(UUID().uuidString).txt")
        try "hello".write(to: badExtURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: badExtURL) }
        #expect(throws: ExportManager.ImportError.self) {
            _ = try ExportManager.shared.importAll(from: badExtURL)
        }

        let badCSVURL = FileManager.default.temporaryDirectory.appendingPathComponent("bad_\(UUID().uuidString).csv")
        try "col1,col2\nval1,val2".write(to: badCSVURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: badCSVURL) }
        #expect(throws: ExportManager.ImportError.self) {
            _ = try ExportManager.shared.importAll(from: badCSVURL)
        }
    }

    // MARK: - 8. Existing v1.x-Origin Library Mutations & History Preservation

    @Test("v1.x-origin migrated films support full editing, merging, camera deletion & stock deletion without breaking finished/loaded history")
    func legacyLibraryMutationsAndHistoryPreservation() async throws {
        let (container, context, manager) = try makeIsolatedEnvironment()
        _ = container
        UserDefaults.standard.set(false, forKey: "migration_rollCentric_v1")

        // 1. Seed a v1.x-era library (nil optionals, unpadded dates, formatless cameras, status=nil finished rolls, duplicate Film rows)
        let kodak = Manufacturer(name: "Kodak", isCustom: false)
        context.insert(kodak)

        let oldTriX = Film(name: "Tri-X", manufacturer: kodak, type: FilmStock.FilmType.bw.rawValue, filmSpeed: 400)
        context.insert(oldTriX)

        // Legacy multi-quantity roll (v1.x) with nil optional fields and unpadded expiry "3/2028"
        let v1Stock = MyFilm(
            id: "v1-trix-batch",
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            quantity: 2,
            expireDate: ["3/2028"],
            comments: "v1 batch",
            film: oldTriX
        )
        v1Stock.isFrozen = nil
        v1Stock.isFridge = nil
        v1Stock.exposures = nil
        v1Stock.createdAt = nil
        v1Stock.updatedAt = nil
        context.insert(v1Stock)

        // Consumed v1.x roll linked to an early v1.4 FinishedFilm (status = nil, camera relationship set, cameraName = nil, comments = nil)
        let v1Consumed = MyFilm(
            id: "v1-trix-finished-backing",
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            quantity: 0,
            expireDate: ["052024"],
            comments: "Paris 2024",
            isFrozen: true,
            exposures: 36,
            film: oldTriX
        )
        v1Consumed.isFridge = nil
        context.insert(v1Consumed)

        let oldCam = Camera(name: "Canon AE-1", format: "") // v1.x camera had no format
        context.insert(oldCam)

        let v1Finished = FinishedFilm(
            id: "v1-finished-roll",
            film: nil, // Early versions relied on myFilm.film
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            camera: oldCam,
            myFilm: v1Consumed,
            quantity: 1,
            loadedAt: Date().addingTimeInterval(-86400 * 200),
            finishedAt: Date().addingTimeInterval(-86400 * 190),
            shotAtISO: nil,
            status: nil,
            developedAt: nil,
            cameraName: nil,
            comments: nil
        )
        context.insert(v1Finished)

        // Also seed a second Film ("Tri-X 400") to test collision-merging an old Film into an existing Film while preserving finished history
        let targetTriX400 = Film(name: "Tri-X 400", manufacturer: kodak, type: FilmStock.FilmType.bw.rawValue, filmSpeed: 400)
        context.insert(targetTriX400)
        let modernRoll = MyFilm(
            id: "modern-trix400-1",
            format: FilmStock.FilmFormat.oneTwenty.rawValue,
            quantity: 1,
            expireDate: ["102028"],
            isFridge: true,
            film: targetTriX400
        )
        context.insert(modernRoll)
        try context.save()

        // 2. Run startup migration & self-healing (simulating app update to v2.8)
        await manager.migrateIfNeeded()

        // Verify v1 multi-quantity stock split into 2 individual active rolls, and unpadded expiry formats cleanly
        let activeOldTriX = manager.filmStocks.filter { $0.name == "Tri-X" && $0.quantity > 0 }
        #expect(activeOldTriX.count == 2)
        #expect(FilmStock.formatExpireDate(activeOldTriX[0].expireDate?.first ?? "") == "03/2028")

        // Verify #86 protection: deleting the old Camera ("Canon AE-1") succeeds AND preserves cameraName on old FinishedFilm!
        #expect(manager.deleteCamera(oldCam) == true)
        let finishedAfterCamDelete = try #require(manager.getFinishedFilms().first { $0.id == "v1-finished-roll" })
        #expect(finishedAfterCamDelete.camera == nil)
        #expect(finishedAfterCamDelete.cameraName == "Canon AE-1")
        #expect(finishedAfterCamDelete.effectiveComments == "Paris 2024")
        #expect(finishedAfterCamDelete.effectiveISO == 400)

        // 3. Update one of the migrated v1 rolls (add exposures, fridge flag, updated expiry & comment)
        manager.updateRolls(
            ids: [activeOldTriX[0].id],
            expireDate: "092029",
            isFrozen: false,
            isFridge: true,
            exposures: 36,
            comments: "Updated v1 roll"
        )
        let updatedRoll = try #require(manager.filmStocks.first { $0.id == activeOldTriX[0].id })
        #expect(updatedRoll.isFridge == true)
        #expect(updatedRoll.isFrozen == false)
        #expect(updatedRoll.exposures == 36)
        #expect(updatedRoll.comments == "Updated v1 roll")

        // 4. Rename old "Tri-X" -> "Tri-X 400" (collision merge into existing Film!) and verify old FinishedFilm re-homes cleanly
        let oldGroup = try #require(manager.groupedFilms().first { $0.name == "Tri-X" })
        manager.updateFilmInfo(
            groupedFilm: oldGroup,
            name: "Tri-X 400",
            manufacturer: "Kodak",
            type: .bw,
            filmSpeed: 400,
            imageName: nil,
            imageSource: ImageSource.autoDetected.rawValue
        )

        let mergedGroups = manager.groupedFilms().filter { $0.name == "Tri-X 400" }
        #expect(mergedGroups.count == 1)
        #expect(mergedGroups[0].formats.reduce(0) { $0 + $1.quantity } == 3) // 2 migrated 35mm + 1 modern 120

        let finishedAfterMerge = try #require(manager.getFinishedFilms().first { $0.id == "v1-finished-roll" })
        #expect(finishedAfterMerge.film?.name == "Tri-X 400")
        #expect(finishedAfterMerge.myFilm?.expireDate == "052024")
        #expect(finishedAfterMerge.myFilm?.exposures == 36)

        // 5. Delete ALL remaining active inventory of "Tri-X 400" (commit 3f23b3b protection):
        // Active inventory must become empty, BUT old FinishedFilm must keep its Film + MyFilm metadata intact!
        let err = manager.deleteGroupedFilm(mergedGroups[0])
        #expect(err == nil)
        #expect(manager.groupedFilms().filter { group in
            group.name == "Tri-X 400" && group.formats.reduce(0, { $0 + $1.quantity }) > 0
        }.isEmpty)

        let finishedAfterStockDelete = try #require(manager.getFinishedFilms().first { $0.id == "v1-finished-roll" })
        #expect(finishedAfterStockDelete.film?.name == "Tri-X 400")
        #expect(finishedAfterStockDelete.cameraName == "Canon AE-1")
        #expect(finishedAfterStockDelete.myFilm?.isFrozen == true)
        #expect(finishedAfterStockDelete.myFilm?.expireDate == "052024")
        #expect(finishedAfterStockDelete.effectiveComments == "Paris 2024")

        // 6. Status transitions & Re-load on the old v1 FinishedFilm (status was originally nil -> defaults to toDevelop -> developed -> reload)
        manager.updateFinishedFilmStatus(finishedAfterStockDelete, status: .developed)
        #expect(finishedAfterStockDelete.status == FinishedFilmStatus.developed.rawValue)
        #expect(finishedAfterStockDelete.developedAt != nil)

        manager.reloadFinishedFilm(finishedAfterStockDelete)
        #expect(manager.getFinishedFilms().isEmpty)
        let reloadedLegacy = try #require(manager.getLoadedFilms().first)
        #expect(reloadedLegacy.film?.name == "Tri-X 400")
        #expect(reloadedLegacy.cameraName == "Canon AE-1")
        #expect(reloadedLegacy.effectiveComments == "Paris 2024")
    }

    @Test("Legacy v2.0 bare-array JSON and old-column CSV backups import cleanly into an existing library without clobbering history")
    func legacyBackupImportIntoExistingLibrary() throws {
        let (container, _, manager) = try makeIsolatedEnvironment()
        _ = container

        // Pre-populate existing user library (1 active film + 1 finished roll)
        let existingStock = FilmStock(
            id: "existing-hp5",
            name: "HP5 Plus",
            manufacturer: "Ilford",
            type: .bw,
            filmSpeed: 400,
            format: .thirtyFive,
            quantity: 2,
            comments: "Existing stock",
            exposures: 36
        )
        manager.addFilmStock(existingStock)
        let firstHp5Id = try #require(manager.filmStocks.first { $0.name == "HP5 Plus" }?.id)
        #expect(manager.loadFilm(filmStockId: firstHp5Id, format: .thirtyFive, cameraName: "Leica M3") == true)
        let loaded = try #require(manager.getLoadedFilms().first)
        manager.unloadFilm(loaded)
        #expect(manager.getFinishedFilms().count == 1)

        // A. Early v2.0 bare-[ExportFilm] JSON backup (missing wrapper object, no isFridge, no comments, no cameras/loaded/finished keys)
        let legacyBareJSON = """
        [
          {
            "manufacturer": "Fujifilm",
            "name": "Pro 400H",
            "type": "color",
            "iso": 400,
            "format": "120",
            "quantity": 3,
            "expiryDate": "05/2023",
            "isFrozen": true
          }
        ]
        """
        let bareJSONURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_v20_\(UUID().uuidString).json")
        try legacyBareJSON.write(to: bareJSONURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: bareJSONURL) }

        let parsedBareJSON = try ExportManager.shared.importAll(from: bareJSONURL)
        #expect(parsedBareJSON.inventory.count == 1)
        try manager.importData(parsedBareJSON)

        // B. Early CSV backup missing newer columns (no Fridge, Comments, DevelopedAt, or # CAMERAS section)
        let legacyCSV = """
        # INVENTORY
        Manufacturer,Film,Type,ISO,Format,Qty,Expiry,Frozen,Exposures
        Kodak,Ektachrome E100,Slide,100,35mm,2,12/2026,No,36

        # FINISHED FILMS
        Manufacturer,Film,Type,ISO,Format,Qty,ShotAtISO,Camera,LoadedAt,FinishedAt,Status
        Kodak,Gold 200,Color,200,35mm,1,200,Olympus OM-1,2024-06-01T10:00:00Z,2024-06-15T18:30:00Z,developed
        """
        let legacyCSVURL = FileManager.default.temporaryDirectory.appendingPathComponent("legacy_v23_\(UUID().uuidString).csv")
        try legacyCSV.write(to: legacyCSVURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: legacyCSVURL) }

        let parsedLegacyCSV = try ExportManager.shared.importAll(from: legacyCSVURL)
        try manager.importData(parsedLegacyCSV)

        // Verify existing library + both legacy imports coexist cleanly
        let activeGroups = manager.groupedFilms().filter { group in
            group.formats.reduce(0, { $0 + $1.quantity }) > 0
        }
        #expect(activeGroups.contains { $0.name == "HP5 Plus" && $0.formats.reduce(0, { $0 + $1.quantity }) == 1 })
        #expect(activeGroups.contains { $0.name == "Pro 400H" && $0.formats.reduce(0, { $0 + $1.quantity }) == 3 })
        #expect(activeGroups.contains { $0.name == "Ektachrome E100" && $0.formats.reduce(0, { $0 + $1.quantity }) == 2 })
        #expect(manager.getFinishedFilms().count == 2) // Existing HP5 Plus + imported Gold 200
    }
}

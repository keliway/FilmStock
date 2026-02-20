//
//  FilmStockDataManager.swift
//  FilmStock
//
//  Data Management using SwiftData
//

import Foundation
import SwiftUI
import SwiftData
import Combine
import WidgetKit

@MainActor
class FilmStockDataManager: ObservableObject {
    @Published var filmStocks: [FilmStock] = []
    @Published var filmStocksVersion: Int = 0
    
    private var modelContext: ModelContext?
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadFilmStocks()
    }
    
    func migrateIfNeeded() async {
        guard let context = modelContext else { return }
        
        // Copy default images to App Group container for widget access (runs once)
        ImageStorage.shared.copyDefaultImagesToAppGroup()
        
        // Load manufacturers from bundle
        await loadManufacturers(context: context)
        
        // Backfill camera names for existing finished films (runs once)
        backfillFinishedFilmsCameraNames(context: context)
        
        // Migrate to roll-centric model: split multi-quantity roll MyFilm entries into individual ones
        migrateToRollCentric(context: context)
    }
    
    private static let rollFormats: Set<String> = ["35", "120", "110", "127", "220"]
    
    private func migrateToRollCentric(context: ModelContext) {
        let migrationKey = "migration_rollCentric_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        let descriptor = FetchDescriptor<MyFilm>()
        guard let allMyFilms = try? context.fetch(descriptor) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }
        
        var created = 0
        for myFilm in allMyFilms {
            guard Self.rollFormats.contains(myFilm.format), myFilm.quantity > 1 else {
                continue
            }
            
            let originalQty = myFilm.quantity
            let dates = myFilm.expireDateArray ?? []
            let frozen = myFilm.isFrozen ?? false
            let now = ISO8601DateFormatter().string(from: Date())
            
            for i in 0..<originalQty {
                let dateForRoll: String?
                if dates.count == 1 {
                    dateForRoll = dates[0]
                } else if i < dates.count {
                    dateForRoll = dates[i]
                } else {
                    dateForRoll = nil
                }
                
                if i == 0 {
                    // Reuse the original MyFilm for the first roll
                    myFilm.quantity = 1
                    myFilm.expireDate = dateForRoll
                } else {
                    let newRoll = MyFilm(
                        id: UUID().uuidString,
                        format: myFilm.format,
                        customFormatName: myFilm.customFormatName,
                        quantity: 1,
                        expireDate: dateForRoll.map { [$0] },
                        comments: myFilm.comments,
                        isFrozen: frozen,
                        exposures: nil,
                        createdAt: myFilm.createdAt ?? now,
                        updatedAt: now,
                        film: nil
                    )
                    context.insert(newRoll)
                    newRoll.film = myFilm.film
                    created += 1
                }
            }
        }
        
        if created > 0 {
            try? context.save()
            loadFilmStocks()
            print("Roll-centric migration: split into \(created) additional individual rolls")
        }
        
        UserDefaults.standard.set(true, forKey: migrationKey)
    }
    
    private func backfillFinishedFilmsCameraNames(context: ModelContext) {
        // Check if backfill already completed
        let backfillKey = "finishedFilms_cameraName_backfilled_v2"
        if UserDefaults.standard.bool(forKey: backfillKey) {
            return
        }
        
        // First, fetch all cameras to have their names available
        let cameraDescriptor = FetchDescriptor<Camera>()
        let availableCameras = (try? context.fetch(cameraDescriptor)) ?? []
        let cameraMap = Dictionary(uniqueKeysWithValues: availableCameras.map { ($0.persistentModelID, $0.name) })
        
        // Now fetch finished films
        let descriptor = FetchDescriptor<FinishedFilm>()
        guard let finishedFilms = try? context.fetch(descriptor) else {
            UserDefaults.standard.set(true, forKey: backfillKey)
            return
        }
        
        var backfilled = 0
        for film in finishedFilms where film.cameraName == nil {
            // Try to get camera using the map (safer than accessing relationship)
            if let camera = film.camera,
               let cameraName = cameraMap[camera.persistentModelID] {
                film.cameraName = cameraName
                backfilled += 1
            }
        }
        
        if backfilled > 0 {
            try? context.save()
            print("Backfilled \(backfilled) finished films with camera names")
        }
        
        // Mark backfill as complete
        UserDefaults.standard.set(true, forKey: backfillKey)
    }
    
    private func loadManufacturers(context: ModelContext) async {
        // Check if manufacturers already exist
        let descriptor = FetchDescriptor<Manufacturer>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return // Already loaded
        }
        
        // Load from manufacturers.json
        var bundleData: Data?
        if let bundleURL = Bundle.main.url(forResource: "manufacturers", withExtension: "json") {
            bundleData = try? Data(contentsOf: bundleURL)
        }
        
        guard let data = bundleData else { return }
        
        do {
            let decoder = JSONDecoder()
            let wrapper = try decoder.decode(ImageStorage.ManufacturersDataWrapper.self, from: data)
            
            for manufacturerInfo in wrapper.manufacturers {
                let manufacturer = Manufacturer(name: manufacturerInfo.name, isCustom: false)
                context.insert(manufacturer)
            }
            
            try context.save()
        } catch {
            // Failed to load manufacturers
        }
    }
    
    func loadFilmStocks() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>()
        guard let myFilms = try? context.fetch(descriptor) else {
            filmStocks = []
            filmStocksVersion &+= 1
                return
        }
        
        // Convert MyFilm to FilmStock for compatibility
        filmStocks = myFilms.compactMap { myFilm -> FilmStock? in
            guard let film = myFilm.film,
                  let type = FilmStock.FilmType(rawValue: film.type),
                  let format = FilmStock.FilmFormat(rawValue: myFilm.format) else {
                return nil
            }
            
            return FilmStock(
                id: myFilm.id,
                name: film.name,
                manufacturer: film.manufacturer?.name ?? "",
                type: type,
                filmSpeed: film.filmSpeed,
                format: format,
                quantity: myFilm.quantity,
                expireDate: myFilm.expireDateArray,
                comments: myFilm.comments,
                isFrozen: myFilm.isFrozen ?? false,
                exposures: myFilm.exposures,
                createdAt: myFilm.createdAt,
                updatedAt: myFilm.updatedAt
            )
        }
    }
    
    func addFilmStock(_ filmStock: FilmStock, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue) -> Bool {
        guard let context = modelContext else { return false }
        
        let manufacturer = findOrCreateManufacturer(name: filmStock.manufacturer, context: context)
        
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        let isRoll = filmStock.format.isRollFormat
        
        if let existingFilm = allFilms.first(where: { film in
            film.name == filmStock.name &&
            film.manufacturer?.name == filmStock.manufacturer
        }) {
            if existingFilm.filmSpeed == filmStock.filmSpeed &&
               existingFilm.type == filmStock.type.rawValue {
                if let imageName = imageName {
                    existingFilm.imageName = imageName
                    existingFilm.imageSource = imageSource
                }
                
                if isRoll {
                    // Roll format: create N individual MyFilm entries (one per roll)
                    createIndividualRolls(filmStock: filmStock, film: existingFilm, context: context)
                } else if let myFilms = existingFilm.myFilms,
                          let existingMyFilm = myFilms.first(where: { $0.format == filmStock.format.rawValue }) {
                    // Sheet/other format: merge into existing entry
                    existingMyFilm.quantity += filmStock.quantity
                    existingMyFilm.customFormatName = filmStock.customFormatName
                    
                    var existingDates = existingMyFilm.expireDateArray ?? []
                    if let newDates = filmStock.expireDate {
                        for newDate in newDates where !newDate.isEmpty {
                            if !existingDates.contains(newDate) {
                                existingDates.append(newDate)
                            }
                        }
                    }
                    existingMyFilm.expireDateArray = existingDates.isEmpty ? nil : existingDates
                    
                    if let newComments = filmStock.comments, !newComments.isEmpty {
                        existingMyFilm.comments = newComments
                    }
                    existingMyFilm.isFrozen = filmStock.isFrozen
                    existingMyFilm.updatedAt = ISO8601DateFormatter().string(from: Date())
                } else {
                    // New format entry for sheets
                    let myFilm = MyFilm(
                        id: filmStock.id,
                        format: filmStock.format.rawValue,
                        customFormatName: filmStock.customFormatName,
                        quantity: filmStock.quantity,
                        expireDate: filmStock.expireDate,
                        comments: filmStock.comments,
                        isFrozen: filmStock.isFrozen,
                        createdAt: filmStock.createdAt,
                        updatedAt: filmStock.updatedAt,
                        film: nil
                    )
                    context.insert(myFilm)
                    myFilm.film = existingFilm
                }
                
                try? context.save()
                loadFilmStocks()
                return true
            } else {
                let film = findOrCreateFilm(
                    name: filmStock.name,
                    manufacturer: manufacturer,
                    type: filmStock.type.rawValue,
                    filmSpeed: filmStock.filmSpeed,
                    imageName: imageName,
                    imageSource: imageSource,
                    context: context
                )
                
                if isRoll {
                    createIndividualRolls(filmStock: filmStock, film: film, context: context)
                } else {
                    let myFilm = MyFilm(
                        id: filmStock.id,
                        format: filmStock.format.rawValue,
                        customFormatName: filmStock.customFormatName,
                        quantity: filmStock.quantity,
                        expireDate: filmStock.expireDate,
                        comments: filmStock.comments,
                        isFrozen: filmStock.isFrozen,
                        createdAt: filmStock.createdAt,
                        updatedAt: filmStock.updatedAt,
                        film: nil
                    )
                    context.insert(myFilm)
                    myFilm.film = film
                }
                
                try? context.save()
                loadFilmStocks()
                return false
            }
        } else {
            let film = findOrCreateFilm(
                name: filmStock.name,
                manufacturer: manufacturer,
                type: filmStock.type.rawValue,
                filmSpeed: filmStock.filmSpeed,
                imageName: imageName,
                imageSource: imageSource,
                context: context
            )
            
            if isRoll {
                createIndividualRolls(filmStock: filmStock, film: film, context: context)
            } else {
                let myFilm = MyFilm(
                    id: filmStock.id,
                    format: filmStock.format.rawValue,
                    customFormatName: filmStock.customFormatName,
                    quantity: filmStock.quantity,
                    expireDate: filmStock.expireDate,
                    comments: filmStock.comments,
                    isFrozen: filmStock.isFrozen,
                    createdAt: filmStock.createdAt,
                    updatedAt: filmStock.updatedAt,
                    film: nil
                )
                context.insert(myFilm)
                myFilm.film = film
            }
            
            try? context.save()
            loadFilmStocks()
            return false
        }
    }
    
    private func createIndividualRolls(filmStock: FilmStock, film: Film, context: ModelContext) {
        let dates = filmStock.expireDate ?? []
        let now = ISO8601DateFormatter().string(from: Date())
        
        for i in 0..<filmStock.quantity {
            let dateForRoll: String?
            if dates.count == 1 {
                dateForRoll = dates[0]
            } else if i < dates.count {
                dateForRoll = dates[i]
            } else {
                dateForRoll = nil
            }
            
            let rollId = i == 0 ? filmStock.id : UUID().uuidString
            let roll = MyFilm(
                id: rollId,
                format: filmStock.format.rawValue,
                customFormatName: filmStock.customFormatName,
                quantity: 1,
                expireDate: dateForRoll.map { [$0] },
                comments: filmStock.comments,
                isFrozen: filmStock.isFrozen,
                exposures: filmStock.exposures,
                createdAt: filmStock.createdAt ?? now,
                updatedAt: filmStock.updatedAt,
                film: nil
            )
            context.insert(roll)
            roll.film = film
        }
    }
    
    /// Updates only the Film-entity-level properties (name, manufacturer, type, speed, image).
    /// Does NOT touch any MyFilm (roll) properties like quantity, expiry, frozen, or exposures.
    func updateFilmInfo(
        groupedFilm: GroupedFilm,
        name: String,
        manufacturer manufacturerName: String,
        type: FilmStock.FilmType,
        filmSpeed: Int,
        imageName: String?,
        imageSource: String
    ) {
        guard let context = modelContext else { return }

        // Locate the Film entity via the groupedFilm's representative MyFilm ID
        let representativeId = groupedFilm.id
        let film: Film?
        let myFilmDescriptor = FetchDescriptor<MyFilm>(predicate: #Predicate { $0.id == representativeId })
        if let ref = try? context.fetch(myFilmDescriptor).first {
            film = ref.film
        } else {
            // Fallback: match by film properties
            let filmDescriptor = FetchDescriptor<Film>()
            film = (try? context.fetch(filmDescriptor))?.first {
                $0.name == groupedFilm.name &&
                $0.manufacturer?.name == groupedFilm.manufacturer &&
                $0.type == groupedFilm.type.rawValue &&
                $0.filmSpeed == groupedFilm.filmSpeed
            }
        }

        guard let film else { return }

        film.name = name
        film.type = type.rawValue
        film.filmSpeed = filmSpeed
        film.imageName = imageName
        film.imageSource = imageSource

        if film.manufacturer?.name != manufacturerName {
            let mfrDescriptor = FetchDescriptor<Manufacturer>(predicate: #Predicate { $0.name == manufacturerName })
            let mfr: Manufacturer
            if let existing = try? context.fetch(mfrDescriptor).first {
                mfr = existing
            } else {
                mfr = Manufacturer(name: manufacturerName, isCustom: true)
                context.insert(mfr)
            }
            film.manufacturer = mfr
        }

        try? context.save()
        loadFilmStocks()
    }

    func updateFilmStock(_ filmStock: FilmStock, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue) {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first,
              let film = myFilm.film else { return }
        
        // Update Film entity properties
        film.name = filmStock.name
        film.type = filmStock.type.rawValue
        film.filmSpeed = filmStock.filmSpeed
        
        // Update manufacturer if it changed
        if film.manufacturer?.name != filmStock.manufacturer {
            // Find or create the new manufacturer
            let manufacturerDescriptor = FetchDescriptor<Manufacturer>(
                predicate: #Predicate { $0.name == filmStock.manufacturer }
            )
            
            let manufacturer: Manufacturer
            if let existing = try? context.fetch(manufacturerDescriptor).first {
                manufacturer = existing
            } else {
                manufacturer = Manufacturer(name: filmStock.manufacturer, isCustom: true)
                context.insert(manufacturer)
    }
    
            film.manufacturer = manufacturer
        }
        
        // Update film's imageName (can be nil to clear it)
        // Check if imageName parameter was explicitly provided (not just default nil)
        // We'll use a different approach: always update if imageName is provided in the call
        // For now, we need to distinguish between "don't change" and "clear"
        // Since we can't do that with optional, we'll always update when called from EditFilmView
        // which always passes imageName (either a value or nil)
        
        // Update imageName and imageSource (custom photos are kept, user can delete manually)
        film.imageName = imageName
        film.imageSource = imageSource
        
        // Update MyFilm
        myFilm.quantity = filmStock.quantity
        myFilm.expireDateArray = filmStock.expireDate
        myFilm.comments = filmStock.comments
        myFilm.isFrozen = filmStock.isFrozen
        myFilm.exposures = filmStock.exposures
        myFilm.updatedAt = ISO8601DateFormatter().string(from: Date())
        
        // If format changed, we need to update it
        if myFilm.format != filmStock.format.rawValue {
            myFilm.format = filmStock.format.rawValue
        }
        
        // Always update customFormatName (can be nil for built-in formats)
        myFilm.customFormatName = filmStock.customFormatName
        
        try? context.save()
        loadFilmStocks()
    }
    
    func deleteFilmStock(_ filmStock: FilmStock) {
        deleteFilmStocks([filmStock])
    }
    
    func isFilmLoaded(_ filmStock: FilmStock) -> Bool {
        guard let context = modelContext else { return false }
        
        // Fetch all LoadedFilm entries
        let loadedFilmDescriptor = FetchDescriptor<LoadedFilm>()
        guard let loadedFilms = try? context.fetch(loadedFilmDescriptor) else { return false }
        
        // Check if any loaded film matches this film
        return loadedFilms.contains { loadedFilm in
            guard let film = loadedFilm.film else { return false }
            return film.name == filmStock.name &&
                   film.manufacturer?.name == filmStock.manufacturer &&
                   film.type == filmStock.type.rawValue &&
                   film.filmSpeed == filmStock.filmSpeed
        }
    }
    
    func deleteFilmStocks(_ filmStocks: [FilmStock]) {
        guard let context = modelContext else { return }
        guard !filmStocks.isEmpty else { return }
        
        // Fetch all MyFilm entries
        let myFilmDescriptor = FetchDescriptor<MyFilm>()
        guard let allMyFilms = try? context.fetch(myFilmDescriptor) else { return }
        
        // Fetch all Film entries
        let filmDescriptor = FetchDescriptor<Film>()
        guard let allFilms = try? context.fetch(filmDescriptor) else { return }
        
        // Track which films we're deleting MyFilms from and which MyFilms are being deleted
        var filmsToCheck: Set<PersistentIdentifier> = []
        var deletedMyFilmIds: Set<String> = []
        
        // Find and delete all matching MyFilms from the database
        for filmStock in filmStocks {
            let myFilmsToDelete = allMyFilms.filter { myFilm in
                guard let film = myFilm.film else { return false }
                return film.name == filmStock.name &&
                       film.manufacturer?.name == filmStock.manufacturer &&
                       film.type == filmStock.type.rawValue &&
                       film.filmSpeed == filmStock.filmSpeed
            }
            
            for myFilm in myFilmsToDelete {
                if let film = myFilm.film {
                    filmsToCheck.insert(film.persistentModelID)
                }
                deletedMyFilmIds.insert(myFilm.id)
                context.delete(myFilm)
            }
        }
        
        // Check if any Films now have zero MyFilm entries and delete them
        for filmId in filmsToCheck {
            if let film = allFilms.first(where: { $0.persistentModelID == filmId }) {
                // Check if this film has any remaining MyFilms (excluding the ones we just deleted)
                let remainingMyFilms = allMyFilms.filter { myFilm in
                    guard let myFilmFilm = myFilm.film else { return false }
                    return myFilmFilm.persistentModelID == filmId && !deletedMyFilmIds.contains(myFilm.id)
                }
                
                // If no MyFilms remain for this film, delete the Film entity too
                if remainingMyFilms.isEmpty {
                    context.delete(film)
                }
            }
        }
        
        // Save to database and reload immediately
        if (try? context.save()) != nil {
            loadFilmStocks()
        }
    }
    
    // MARK: - Roll-level mutations (used by RollGroupEditSheet)

    /// Delete specific MyFilm entries by their IDs (targeted, does not touch other rolls).
    func deleteRollsById(_ ids: [String]) {
        guard let context = modelContext, !ids.isEmpty else { return }

        let myFilmDescriptor = FetchDescriptor<MyFilm>()
        guard let allMyFilms = try? context.fetch(myFilmDescriptor) else { return }

        let filmDescriptor = FetchDescriptor<Film>()
        guard let allFilms = try? context.fetch(filmDescriptor) else { return }

        let idSet = Set(ids)
        var filmsToCheck: Set<PersistentIdentifier> = []

        for myFilm in allMyFilms where idSet.contains(myFilm.id) {
            if let film = myFilm.film { filmsToCheck.insert(film.persistentModelID) }
            context.delete(myFilm)
        }

        // Clean up Film entities that now have no remaining MyFilms
        for filmPID in filmsToCheck {
            if let film = allFilms.first(where: { $0.persistentModelID == filmPID }) {
                let remaining = allMyFilms.filter {
                    guard let f = $0.film else { return false }
                    return f.persistentModelID == filmPID && !idSet.contains($0.id)
                }
                if remaining.isEmpty { context.delete(film) }
            }
        }

        try? context.save()
        loadFilmStocks()
    }

    /// Update expiry date, frozen state, exposures and comments for a set of MyFilm entries by ID.
    func updateRolls(ids: [String], expireDate: String?, isFrozen: Bool, exposures: Int?, comments: String?) {
        guard let context = modelContext, !ids.isEmpty else { return }

        let descriptor = FetchDescriptor<MyFilm>()
        guard let allMyFilms = try? context.fetch(descriptor) else { return }

        let idSet = Set(ids)
        let now = ISO8601DateFormatter().string(from: Date())
        for myFilm in allMyFilms where idSet.contains(myFilm.id) {
            myFilm.expireDate = expireDate
            myFilm.isFrozen = isFrozen
            myFilm.exposures = exposures
            myFilm.comments = comments?.isEmpty == false ? comments : nil
            myFilm.updatedAt = now
        }

        try? context.save()
        loadFilmStocks()
    }

    /// Create `count` new individual rolls that match the film of the given reference MyFilm ID.
    @discardableResult
    func addRolls(count: Int, matchingFilmStockId referenceId: String, expireDate: String?, isFrozen: Bool, exposures: Int?, comments: String?) -> Bool {
        guard let context = modelContext, count > 0 else { return false }

        let descriptor = FetchDescriptor<MyFilm>(predicate: #Predicate { $0.id == referenceId })
        guard let ref = try? context.fetch(descriptor).first,
              let film = ref.film else { return false }

        let now = ISO8601DateFormatter().string(from: Date())
        for _ in 0..<count {
            let roll = MyFilm(
                id: UUID().uuidString,
                format: ref.format,
                customFormatName: ref.customFormatName,
                quantity: 1,
                expireDate: expireDate.map { [$0] },
                comments: comments?.isEmpty == false ? comments : nil,
                isFrozen: isFrozen,
                exposures: exposures,
                createdAt: now,
                updatedAt: now
            )
            context.insert(roll)
            roll.film = film
        }

        try? context.save()
        loadFilmStocks()
        return true
    }

    func groupedFilms() -> [GroupedFilm] {
        guard let context = modelContext else { return [] }
        
        let descriptor = FetchDescriptor<Film>()
        guard let films = try? context.fetch(descriptor) else { return [] }
        
        let today = Date()
        var groups: [String: GroupedFilm] = [:]
        
        for film in films {
            guard let manufacturer = film.manufacturer,
                  let type = FilmStock.FilmType(rawValue: film.type) else {
                continue
            }
            
            let key = "\(film.name)_\(manufacturer.name)_\(film.type)_\(film.filmSpeed)"
            
            if groups[key] == nil {
                let firstMyFilmId = film.myFilms?.first?.id ?? UUID().uuidString
                groups[key] = GroupedFilm(
                    id: firstMyFilmId,
                    name: film.name,
                    manufacturer: manufacturer.name,
                    type: type,
                    filmSpeed: film.filmSpeed,
                    imageName: film.imageName,
                    imageSource: film.imageSource,
                    formats: []
                )
            }
            
            guard let myFilms = film.myFilms else { continue }
            
            // For roll formats: aggregate individual MyFilm entries per format into one FormatInfo
            // For sheet formats: keep as-is (one FormatInfo per MyFilm)
            var rollBuckets: [String: [MyFilm]] = [:] // keyed by format rawValue
            
            for myFilm in myFilms {
                guard let format = FilmStock.FilmFormat(rawValue: myFilm.format) else { continue }
                
                if format.isRollFormat {
                    let bucketKey = myFilm.format
                    rollBuckets[bucketKey, default: []].append(myFilm)
                } else {
                    // Sheet/other format: one FormatInfo per MyFilm (unchanged behavior)
                    groups[key]?.formats.append(GroupedFilm.FormatInfo(
                        id: myFilm.id,
                        format: format,
                        customFormatName: myFilm.customFormatName,
                        quantity: myFilm.quantity,
                        expireDate: myFilm.expireDateArray,
                        isFrozen: myFilm.isFrozen ?? false,
                        filmId: myFilm.id,
                        comments: myFilm.comments,
                        rollIds: [myFilm.id],
                        frozenCount: (myFilm.isFrozen ?? false) ? myFilm.quantity : 0,
                        expiredCount: Self.countExpiredEntries(myFilm.expireDateArray, today: today) > 0 ? myFilm.quantity : 0
                    ))
                }
            }
            
            // Aggregate each roll bucket into a single FormatInfo
            for (formatRaw, rolls) in rollBuckets {
                guard let format = FilmStock.FilmFormat(rawValue: formatRaw) else { continue }
                let totalQty = rolls.reduce(0) { $0 + $1.quantity }
                // Deduplicate dates so identical expiry dates across rolls show once
                let allDates: [String] = {
                    var seen = Set<String>()
                    return rolls.compactMap { $0.expireDateArray }.flatMap { $0 }.filter { seen.insert($0).inserted }
                }()
                let anyFrozen = rolls.contains { $0.isFrozen ?? false }
                let frozenCount = rolls.filter { $0.isFrozen ?? false }.count
                let expiredCount = rolls.filter { Self.isMyFilmExpired($0, today: today) }.count
                let allIds = rolls.map { $0.id }
                let firstRoll = rolls.first!
                let allComments = rolls.compactMap { $0.comments }.filter { !$0.isEmpty }
                
                groups[key]?.formats.append(GroupedFilm.FormatInfo(
                    id: firstRoll.id,
                    format: format,
                    customFormatName: firstRoll.customFormatName,
                    quantity: totalQty,
                    expireDate: allDates.isEmpty ? nil : allDates,
                    isFrozen: anyFrozen,
                    filmId: firstRoll.id,
                    comments: allComments.first,
                    rollIds: allIds,
                    frozenCount: frozenCount,
                    expiredCount: expiredCount
                ))
            }
        }
        
        return Array(groups.values).sorted { film1, film2 in
            if film1.manufacturer != film2.manufacturer {
                return film1.manufacturer < film2.manufacturer
            }
            return film1.name < film2.name
        }
    }
    
    private static func isMyFilmExpired(_ myFilm: MyFilm, today: Date) -> Bool {
        guard let dates = myFilm.expireDateArray, !dates.isEmpty else { return false }
        return countExpiredEntries(dates, today: today) > 0
    }
    
    private static func countExpiredEntries(_ dates: [String]?, today: Date) -> Int {
        guard let dates = dates else { return 0 }
        return dates.filter { dateString in
            guard let parsed = FilmStock.parseExpireDate(dateString) else { return false }
            return parsed < today
        }.count
    }
    
    // MARK: - Manufacturer Management
    
    func getAllManufacturers() -> [Manufacturer] {
        guard let context = modelContext else { return [] }
        
        // Fetch all manufacturers
        let manufacturerDescriptor = FetchDescriptor<Manufacturer>()
        guard let allManufacturers = try? context.fetch(manufacturerDescriptor) else { return [] }
        
        // Fetch all films to count usage
        let filmDescriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(filmDescriptor)) ?? []
        
        // Count total quantity for each manufacturer
        var manufacturerUsage: [String: Int] = [:]
        for film in allFilms {
            guard let manufacturerName = film.manufacturer?.name else { continue }
            let totalQuantity = film.myFilms?.reduce(0) { $0 + $1.quantity } ?? 0
            manufacturerUsage[manufacturerName, default: 0] += totalQuantity
        }
        
        // Define pinned manufacturers (case-insensitive matching)
        let pinnedNames = ["Kodak", "Ilford", "Fomapan", "Cinestill"]
        
        // Separate pinned and unpinned manufacturers
        var pinned: [Manufacturer] = []
        var unpinned: [Manufacturer] = []
        
        for manufacturer in allManufacturers {
            if pinnedNames.contains(where: { $0.localizedCaseInsensitiveCompare(manufacturer.name) == .orderedSame }) {
                pinned.append(manufacturer)
            } else {
                unpinned.append(manufacturer)
            }
        }
        
        // Sort pinned manufacturers in the order they appear in pinnedNames array
        pinned.sort { m1, m2 in
            let index1 = pinnedNames.firstIndex { $0.localizedCaseInsensitiveCompare(m1.name) == .orderedSame } ?? Int.max
            let index2 = pinnedNames.firstIndex { $0.localizedCaseInsensitiveCompare(m2.name) == .orderedSame } ?? Int.max
            return index1 < index2
        }
        
        // Sort unpinned manufacturers by usage (most frequent first), then alphabetically
        unpinned.sort { m1, m2 in
            let usage1 = manufacturerUsage[m1.name] ?? 0
            let usage2 = manufacturerUsage[m2.name] ?? 0
            if usage1 != usage2 {
                return usage1 > usage2 // Most used first
            }
            return m1.name < m2.name // Alphabetical for same usage
        }
        
        // Combine: pinned first, then unpinned
        return pinned + unpinned
    }
    
    func addManufacturer(name: String) -> Manufacturer {
        guard let context = modelContext else {
            return Manufacturer(name: name, isCustom: true)
        }
        
        let manufacturer = Manufacturer(name: name, isCustom: true)
        context.insert(manufacturer)
        try? context.save()
        return manufacturer
    }
    
    func deleteManufacturer(_ manufacturer: Manufacturer) -> Bool {
        guard let context = modelContext else { return false }
        
        // Only allow deletion of custom manufacturers
        guard manufacturer.isCustom else { return false }
        
        // Check if any films use this manufacturer - fetch all and filter in memory
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        let filmsUsingManufacturer = allFilms.filter { film in
            film.manufacturer?.name == manufacturer.name
        }
        
        if !filmsUsingManufacturer.isEmpty {
            // Don't delete if films are using it
            return false
        }
        
        context.delete(manufacturer)
        try? context.save()
        return true
    }
    
    // MARK: - Helper Methods
    
    private func findOrCreateManufacturer(name: String, context: ModelContext) -> Manufacturer {
        let descriptor = FetchDescriptor<Manufacturer>(
            predicate: #Predicate { $0.name == name }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let manufacturer = Manufacturer(name: name, isCustom: true)
        context.insert(manufacturer)
        // Don't save here - save will happen after all relationships are established
        return manufacturer
    }
    
    private func findOrCreateFilm(name: String, manufacturer: Manufacturer, type: String, filmSpeed: Int, imageName: String? = nil, imageSource: String = ImageSource.autoDetected.rawValue, context: ModelContext) -> Film {
        // Fetch all films and filter in memory to avoid complex predicate issues
        let descriptor = FetchDescriptor<Film>()
        let allFilms = (try? context.fetch(descriptor)) ?? []
        
        // Find existing film matching criteria
        if let existing = allFilms.first(where: { film in
            film.name == name &&
            film.manufacturer?.name == manufacturer.name &&
            film.type == type &&
            film.filmSpeed == filmSpeed
        }) {
            // Update imageName and imageSource if provided
            if let imageName = imageName {
                existing.imageName = imageName
                existing.imageSource = imageSource
                try? context.save()
            }
            return existing
        }
        
        let film = Film(
            name: name,
            manufacturer: nil,  // Don't set relationship in initializer
            type: type,
            filmSpeed: filmSpeed,
            imageName: imageName,
            imageSource: imageSource
        )
        context.insert(film)
        // Now establish the relationship after both objects are in the context
        film.manufacturer = manufacturer
        try? context.save()
        return film
    }
    
    /// Get the imageName for a FilmStock
    func getImageName(for filmStock: FilmStock) -> String? {
        guard let context = modelContext else { return nil }
        
        let descriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStock.id }
        )
        
        guard let myFilm = try? context.fetch(descriptor).first,
              let film = myFilm.film else {
            return nil
        }
        
        return film.imageName
    }
    
    // MARK: - Camera Management
    
    func getAllCameras() -> [Camera] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Camera>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func addCamera(name: String) -> Camera {
        guard let context = modelContext else {
            return Camera(name: name)
        }
        
        // Check if camera already exists
        let descriptor = FetchDescriptor<Camera>(
            predicate: #Predicate { $0.name == name }
        )
        
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        
        let camera = Camera(name: name)
        context.insert(camera)
        try? context.save()
        return camera
    }
    
    func deleteCamera(_ camera: Camera) -> Bool {
        guard let context = modelContext else { return false }
        
        // Check if any loaded films use this camera
        let descriptor = FetchDescriptor<LoadedFilm>()
        let allLoadedFilms = (try? context.fetch(descriptor)) ?? []
        
        let filmsUsingCamera = allLoadedFilms.filter { loadedFilm in
            loadedFilm.camera?.name == camera.name
        }
        
        if !filmsUsingCamera.isEmpty {
            // Don't delete if films are loaded in this camera
            return false
        }
        
        context.delete(camera)
        try? context.save()
        return true
    }
    
    // MARK: - Loaded Film Management
    
    func getLoadedFilms() -> [LoadedFilm] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<LoadedFilm>(
            sortBy: [SortDescriptor(\.loadedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func getFinishedFilms() -> [FinishedFilm] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<FinishedFilm>(
            sortBy: [SortDescriptor(\.finishedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
    
    func loadFilm(filmStockId: String, format: FilmStock.FilmFormat, cameraName: String, quantity: Int = 1, shotAtISO: Int? = nil) -> Bool {
        guard let context = modelContext else { return false }
        
        let myFilmDescriptor = FetchDescriptor<MyFilm>(
            predicate: #Predicate { $0.id == filmStockId }
        )
        
        guard let myFilm = try? context.fetch(myFilmDescriptor).first,
              myFilm.format == format.rawValue,
              myFilm.quantity >= quantity,
              quantity > 0,
              let film = myFilm.film else {
            return false
        }
        
        let cameraDescriptor = FetchDescriptor<Camera>(
            predicate: #Predicate { $0.name == cameraName }
        )
        
        var camera: Camera
        if let existing = try? context.fetch(cameraDescriptor).first {
            camera = existing
        } else {
            camera = Camera(name: cameraName)
            context.insert(camera)
        }
        
        let isoToStore: Int? = (shotAtISO != nil && shotAtISO != film.filmSpeed) ? shotAtISO : nil
        
        let loadedFilm = LoadedFilm(
            id: UUID().uuidString,
            film: nil,
            format: format.rawValue,
            camera: nil,
            myFilm: nil,
            quantity: quantity,
            shotAtISO: isoToStore
        )
        context.insert(loadedFilm)
        loadedFilm.film = film
        loadedFilm.camera = camera
        loadedFilm.myFilm = myFilm
        
        // For roll formats: consume the individual roll (set to 0)
        // For sheet formats: decrement by the amount loaded
        if format.isRollFormat {
            myFilm.quantity = 0
        } else {
            myFilm.quantity = max(0, myFilm.quantity - quantity)
        }
        
        try? context.save()
        loadFilmStocks()
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
        return true
    }
    
    func unloadFilm(_ loadedFilm: LoadedFilm, quantity: Int? = nil) {
        guard let context = modelContext else { return }
        
        // Track finished films count
        let quantityFinished: Int
        
        // If quantity is specified, unload only that amount
        if let quantityToUnload = quantity {
            quantityFinished = min(quantityToUnload, loadedFilm.quantity)
            recordFinishedFilm(from: loadedFilm, quantity: quantityFinished)
            // Decrease the loaded quantity
            loadedFilm.quantity = max(0, loadedFilm.quantity - quantityToUnload)
            
            // If quantity reaches 0, delete the loaded film entry
            if loadedFilm.quantity == 0 {
                context.delete(loadedFilm)
            }
        } else {
            quantityFinished = loadedFilm.quantity
            recordFinishedFilm(from: loadedFilm, quantity: quantityFinished)
            // Don't restore quantity - unloading means the film was used
            // Just delete the loaded film entry
            context.delete(loadedFilm)
        }
        
        // Increment the finished films counter
        incrementFinishedFilmsCount(by: quantityFinished)
        
        try? context.save()
        loadFilmStocks() // Refresh the list
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
    }
    
    private func recordFinishedFilm(from loadedFilm: LoadedFilm, quantity: Int) {
        guard let context = modelContext, quantity > 0 else { return }
        
        // Capture camera name as a snapshot (preserves name even if camera is deleted later)
        let cameraName = loadedFilm.camera?.name
        
        let finished = FinishedFilm(
            id: UUID().uuidString,
            film: nil,
            format: loadedFilm.format,
            camera: nil,
            myFilm: nil,
            quantity: quantity,
            loadedAt: loadedFilm.loadedAt,
            finishedAt: Date(),
            shotAtISO: loadedFilm.shotAtISO,
            status: FinishedFilmStatus.toDevelop.rawValue,
            cameraName: cameraName
        )
        context.insert(finished)
        finished.film = loadedFilm.film
        finished.camera = loadedFilm.camera
        finished.myFilm = loadedFilm.myFilm
    }
    
    func deleteLoadedFilm(_ loadedFilm: LoadedFilm) {
        guard let context = modelContext else { return }
        
        // Restore the quantity to MyFilm (since the film wasn't used)
        if let myFilm = loadedFilm.myFilm {
            if let format = FilmStock.FilmFormat(rawValue: loadedFilm.format), format.isRollFormat {
                myFilm.quantity = 1
            } else {
                myFilm.quantity += loadedFilm.quantity
            }
        }
        
        context.delete(loadedFilm)
        
        try? context.save()
        loadFilmStocks()
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
    }
    
    func reloadFinishedFilm(_ finishedFilm: FinishedFilm) {
        guard let context = modelContext else { return }
        
        // Create a new LoadedFilm entry with the original data
        let loadedFilm = LoadedFilm(
            id: UUID().uuidString,
            film: nil,
            format: finishedFilm.format,
            camera: nil,
            myFilm: nil,
            quantity: finishedFilm.quantity,
            loadedAt: finishedFilm.loadedAt,
            shotAtISO: finishedFilm.shotAtISO
        )
        
        context.insert(loadedFilm)
        loadedFilm.film = finishedFilm.film
        loadedFilm.camera = finishedFilm.camera
        loadedFilm.myFilm = finishedFilm.myFilm
        
        // Delete the finished film entry
        context.delete(finishedFilm)
        
        // Decrement the finished films counter
        let currentCount = getFinishedFilmsCount()
        if currentCount >= finishedFilm.quantity {
            UserDefaults.standard.set(currentCount - finishedFilm.quantity, forKey: Self.finishedFilmsKey)
        }
        
        try? context.save()
        loadFilmStocks() // Refresh the list
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
        WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
    }
    
    func updateFinishedFilmStatus(_ finishedFilm: FinishedFilm, status: FinishedFilmStatus) {
        guard let context = modelContext else { return }
        finishedFilm.status = status.rawValue
        try? context.save()
        loadFilmStocks()
        NotificationCenter.default.post(name: NSNotification.Name("LoadedFilmsChanged"), object: nil)
    }
    
    private static let finishedFilmsKey = "stats_finishedFilmsCount"
    
    func getFinishedFilmsCount() -> Int {
        UserDefaults.standard.integer(forKey: Self.finishedFilmsKey)
    }
    
    private func incrementFinishedFilmsCount(by amount: Int) {
        let current = getFinishedFilmsCount()
        UserDefaults.standard.set(current + amount, forKey: Self.finishedFilmsKey)
    }
    
    func saveContext() {
        guard let context = modelContext else { return }
        try? context.save()
        loadFilmStocks()
    }
}

private struct ManufacturersDataWrapper: Codable {
    let manufacturers: [String]
}

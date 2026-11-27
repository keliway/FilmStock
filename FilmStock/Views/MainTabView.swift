//
//  MainTabView.swift
//  FilmStock
//
//  Main tab-based navigation (iOS HIG)
//

import SwiftUI
import SwiftData

struct MainTabView: View {
    @EnvironmentObject var dataManager: FilmStockDataManager
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: Int = 0
    @State private var selectedLoadedFilmId: String? = nil
    @State private var showingWelcome = false
    @State private var showingWhatsNew = false
    @AppStorage("seenWhatsNewVersion") private var seenWhatsNewVersion: String = ""

    var body: some View {
        TabView(selection: $selectedTab) {
            BrowseView()
                .tabItem {
                    Label("tab.myFilms", systemImage: "film")
                }
                .tag(0)
            
            LoadedFilmsView(selectedFilmId: $selectedLoadedFilmId)
                .tabItem {
                    Label("tab.loadedFilms", systemImage: "camera")
                }
                .tag(1)
            
            NavigationStack {
                CollectionView()
            }
                .tabItem {
                Label("tab.collection", systemImage: "camera.viewfinder")
            }
            .tag(2)
        }
        .task {
            dataManager.setModelContext(modelContext)
            await dataManager.migrateIfNeeded()

            if ProcessInfo.processInfo.arguments.contains("-UITestSeedCustomPhotos") {
                seedUITestCustomPhotos()
            }
            if ProcessInfo.processInfo.arguments.contains("-UITestSeedLegacyLibrary") {
                await seedUITestLegacyLibrary()
            }

            // Show welcome screen on very first launch
            if !OnboardingManager.shared.hasCompletedOnboarding {
                seenWhatsNewVersion = whatsNewVersion
                showingWelcome = true
            } else if seenWhatsNewVersion != whatsNewVersion {
                // Show what's new sheet after an update (existing users only)
                showingWhatsNew = true
            }
        }
        .fullScreenCover(isPresented: $showingWelcome, onDismiss: {
            NotificationCenter.default.post(name: NSNotification.Name("OnboardingCompleted"), object: nil)
        }) {
            WelcomeView(isPresented: $showingWelcome)
        }
        .sheet(isPresented: $showingWhatsNew, onDismiss: {
            seenWhatsNewVersion = whatsNewVersion
        }) {
            WhatsNewView(isPresented: $showingWhatsNew)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMyFilms"))) { _ in
            selectedTab = 0
        }
        .onOpenURL { url in
            // Handle deep link from widget
            guard url.scheme == "filmstock" else { return }
            
            if url.host == "loadedfilms" || url.host == "loadedfilm" {
                selectedTab = 1
                
                // Extract target film ID if provided (query param ?id=... or path /...)
                let filmId: String? = {
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let queryId = components.queryItems?.first(where: { $0.name == "id" })?.value,
                       !queryId.isEmpty {
                        return queryId
                    }
                    let pathId = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }.first
                    return pathId
                }()
                
                if let filmId = filmId {
                    selectedLoadedFilmId = filmId
                }
            }
        }
    }

    private func seedUITestCustomPhotos() {
        guard dataManager.filmStocks.isEmpty else { return }
        let samples: [(manufacturer: String, name: String, type: FilmStock.FilmType, speed: Int, color: UIColor)] = [
            ("Ilford", "HP5 Plus", .bw, 400, .darkGray),
            ("Kodak", "Portra 400", .color, 400, .systemOrange)
        ]
        for sample in samples {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 240))
            let img = renderer.image { ctx in
                sample.color.setFill()
                ctx.fill(CGRect(x: 0, y: 0, width: 240, height: 240))
            }
            if let savedFile = ImageStorage.shared.saveImage(img, forManufacturer: sample.manufacturer, filmName: sample.name) {
                let stock = FilmStock(
                    id: UUID().uuidString,
                    name: sample.name,
                    manufacturer: sample.manufacturer,
                    type: sample.type,
                    filmSpeed: sample.speed,
                    format: .thirtyFive,
                    quantity: 2,
                    exposures: 36
                )
                _ = dataManager.addFilmStock(
                    stock,
                    imageName: "\(sample.manufacturer)/\(savedFile)",
                    imageSource: ImageSource.custom.rawValue
                )
            }
        }
    }

    private func seedUITestLegacyLibrary() async {
        guard dataManager.filmStocks.isEmpty else { return }

        // Simulate a long-time user library created in v1.x and migrated forward through v2.x:
        let mfrs = (try? modelContext.fetch(FetchDescriptor<Manufacturer>())) ?? []
        let kodak = mfrs.first(where: { $0.name == "Kodak" }) ?? {
            let m = Manufacturer(name: "Kodak", isCustom: false)
            modelContext.insert(m)
            return m
        }()
        let ilford = mfrs.first(where: { $0.name == "Ilford" }) ?? {
            let m = Manufacturer(name: "Ilford", isCustom: false)
            modelContext.insert(m)
            return m
        }()

        // 1. Legacy Film added in v1.x (nil imageName, unpadded expiry, nil optional flags on MyFilm)
        let triX = Film(name: "Tri-X 400", manufacturer: kodak, type: FilmStock.FilmType.bw.rawValue, filmSpeed: 400)
        modelContext.insert(triX)

        // Pre-roll-centric multi-quantity MyFilm (quantity = 2) with nil optionals -> migrated via migrateToRollCentric
        let legacyStockRoll = MyFilm(
            id: "legacy-trix-stock",
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            quantity: 2,
            expireDate: ["3/2028"],
            comments: nil,
            film: triX
        )
        legacyStockRoll.isFrozen = nil
        legacyStockRoll.isFridge = nil
        legacyStockRoll.exposures = nil
        legacyStockRoll.createdAt = nil
        legacyStockRoll.updatedAt = nil
        modelContext.insert(legacyStockRoll)

        // Consumed v1.x roll backing an old FinishedFilm (status = nil, camera relationship still attached, cameraName = nil)
        let consumedTriXRoll = MyFilm(
            id: "legacy-trix-consumed",
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            quantity: 0,
            expireDate: ["112025"],
            comments: "Berlin 2024",
            film: triX
        )
        consumedTriXRoll.isFrozen = nil
        consumedTriXRoll.isFridge = nil
        modelContext.insert(consumedTriXRoll)

        // Legacy v1.x camera with empty format ("")
        let legacyCam = Camera(name: "Nikon FM2", format: "")
        modelContext.insert(legacyCam)

        let legacyFinished = FinishedFilm(
            id: "legacy-finished-1",
            film: triX,
            format: FilmStock.FilmFormat.thirtyFive.rawValue,
            camera: legacyCam,
            myFilm: consumedTriXRoll,
            quantity: 1,
            loadedAt: Date().addingTimeInterval(-86400 * 120),
            finishedAt: Date().addingTimeInterval(-86400 * 110),
            shotAtISO: nil,
            status: nil,
            developedAt: nil,
            cameraName: nil,
            comments: nil
        )
        modelContext.insert(legacyFinished)

        // 2. Legacy LoadedFilm (pre-v2.8: comments = nil on LoadedFilm, camera relationship set, cameraName = nil)
        let fp4 = Film(name: "FP4 Plus", manufacturer: ilford, type: FilmStock.FilmType.bw.rawValue, filmSpeed: 125)
        modelContext.insert(fp4)
        let loadedBackingRoll = MyFilm(
            id: "legacy-fp4-loaded",
            format: FilmStock.FilmFormat.oneTwenty.rawValue,
            quantity: 0,
            comments: "Alps hike",
            film: fp4
        )
        loadedBackingRoll.isFrozen = nil
        loadedBackingRoll.isFridge = nil
        modelContext.insert(loadedBackingRoll)

        let activeLegacyCam = Camera(name: "Rolleiflex 2.8F", format: "")
        modelContext.insert(activeLegacyCam)

        let legacyLoaded = LoadedFilm(
            id: "legacy-loaded-1",
            film: fp4,
            format: FilmStock.FilmFormat.oneTwenty.rawValue,
            camera: activeLegacyCam,
            myFilm: loadedBackingRoll,
            quantity: 1,
            loadedAt: Date().addingTimeInterval(-86400 * 30),
            shotAtISO: nil,
            cameraName: nil,
            comments: nil
        )
        modelContext.insert(legacyLoaded)

        try? modelContext.save()
        UserDefaults.standard.set(1, forKey: "stats_finishedFilmsCount")
        UserDefaults.standard.set(false, forKey: "migration_rollCentric_v1")
        await dataManager.migrateIfNeeded()
    }
}

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
}

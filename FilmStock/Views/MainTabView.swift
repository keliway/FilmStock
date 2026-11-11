//
//  MainTabView.swift
//  FilmStock
//
//  Main tab-based navigation (iOS HIG)
//

import SwiftUI
import SwiftData
import WidgetKit

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
            NavigationStack {
            BrowseView()
            }
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

            // Show welcome screen on very first launch
            if !OnboardingManager.shared.hasCompletedOnboarding {
                showingWelcome = true
            } else if seenWhatsNewVersion != whatsNewVersion {
                // Show what's new sheet after an update (existing users only)
                showingWhatsNew = true
            }
        }
        .fullScreenCover(isPresented: $showingWelcome) {
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
            } else if url.host == "widget" {
                // Handle widget navigation
                let appGroupID = "group.app.halbe.no.FilmStock"
                if let userDefaults = UserDefaults(suiteName: appGroupID) {
                    var currentIndex = userDefaults.integer(forKey: "currentFilmIndex")
                    
                    if url.path == "/previous" {
                        currentIndex = max(0, currentIndex - 1)
                    } else if url.path == "/next" {
                        currentIndex = currentIndex + 1 // Will be clamped by widget
                    }
                    
                    userDefaults.set(currentIndex, forKey: "currentFilmIndex")
                    
                    // Reload widget timeline
                    WidgetCenter.shared.reloadTimelines(ofKind: "LoadedFilmsWidget")
                }
            }
        }
    }
}

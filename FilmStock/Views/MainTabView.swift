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
    @State private var showingWelcome = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
            BrowseView()
            }
            .tabItem {
                Label("My Films", systemImage: "film")
            }
            .tag(0)
            
            LoadedFilmsView()
                .tabItem {
                    Label("Loaded Films", systemImage: "camera")
                }
            .tag(1)
            
            NavigationStack {
                CollectionView()
            }
                .tabItem {
                Label("My Collection", systemImage: "camera.viewfinder")
            }
            .tag(2)
        }
        .task {
            dataManager.setModelContext(modelContext)
            await dataManager.migrateIfNeeded()
            
            // Show welcome screen on first launch
            if !OnboardingManager.shared.hasCompletedOnboarding {
                showingWelcome = true
            }
        }
        .fullScreenCover(isPresented: $showingWelcome) {
            WelcomeView(isPresented: $showingWelcome)
        }
        .onOpenURL { url in
            // Handle deep link from widget
            if url.scheme == "filmstock" {
                if url.host == "loadedfilms" {
                    selectedTab = 1
                } else if url.host == "widget" {
                    // Handle widget navigation
                    let appGroupID = "group.halbe.no.FilmStock"
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
}


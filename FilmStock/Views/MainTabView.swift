//
//  MainTabView.swift
//  FilmStock
//
//  Main tab-based navigation (iOS HIG)
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            BrowseView()
                .tabItem {
                    Label("Browse", systemImage: "square.grid.2x2")
                }
            
            ManageView()
                .tabItem {
                    Label("Manage", systemImage: "gearshape.fill")
                }
        }
    }
}


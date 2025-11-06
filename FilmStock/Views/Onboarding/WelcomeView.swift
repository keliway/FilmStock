//
//  WelcomeView.swift
//  FilmStock
//
//  Welcome screen for new users
//

import SwiftUI

struct WelcomeView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    
    private let pages: [WelcomePage] = [
        WelcomePage(
            icon: "film",
            title: "Welcome to FilmStock",
            description: "Your personal film photography companion. Track your film collection, manage loaded films, and never forget what's in your camera."
        ),
        WelcomePage(
            icon: "plus.circle.fill",
            title: "Build Your Collection",
            description: "Add films to your collection, track quantities, and organize by manufacturer, type, and format. Take photos of your film reminder cards for quick reference."
        ),
        WelcomePage(
            icon: "camera.fill",
            title: "Track Loaded Films",
            description: "Keep track of what film is currently loaded in your cameras. Swipe to unload when you're done shooting."
        ),
        WelcomePage(
            icon: "square.grid.2x2.fill",
            title: "Home Screen Widget",
            description: "Add the FilmStock widget to your home screen to see your loaded films at a glance. Perfect for quick reference while shooting."
        )
    ]
    
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        WelcomePageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
                
                // Bottom buttons
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                    } else {
                        Button {
                            withAnimation {
                                currentPage = pages.count - 1
                            }
                        } label: {
                            Text("Skip")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private func completeOnboarding() {
        OnboardingManager.shared.hasCompletedOnboarding = true
        withAnimation {
            isPresented = false
        }
    }
}

struct WelcomePage {
    let icon: String
    let title: String
    let description: String
}

struct WelcomePageView: View {
    let page: WelcomePage
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
                .symbolEffect(.bounce, value: page.icon)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
}


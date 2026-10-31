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
    
    private var pages: [WelcomePage] {
        [
            WelcomePage(
                icon: "film",
                title: NSLocalizedString("onboarding.welcome.title", comment: ""),
                description: NSLocalizedString("onboarding.welcome.subtitle", comment: "")
            ),
            WelcomePage(
                icon: "plus.circle.fill",
                title: NSLocalizedString("onboarding.feature1.title", comment: ""),
                description: NSLocalizedString("onboarding.feature1.description", comment: "")
            ),
            WelcomePage(
                icon: "camera.fill",
                title: NSLocalizedString("onboarding.feature2.title", comment: ""),
                description: NSLocalizedString("onboarding.feature2.description", comment: "")
            ),
            WelcomePage(
                icon: "square.grid.2x2.fill",
                title: NSLocalizedString("onboarding.feature3.title", comment: ""),
                description: NSLocalizedString("onboarding.feature3.description", comment: "")
            )
        ]
    }
    
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
                            Text("onboarding.getStarted")
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
                            Text("action.skip")
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


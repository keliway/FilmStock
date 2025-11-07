//
//  AboutView.swift
//  FilmStock
//
//  About information for the app
//

import SwiftUI

struct AboutView: View {
    @State private var showMailError = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon
                Image(systemName: "film.stack")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.top, 32)
                
                // App Name
                Text("FilmStock")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Version
                Text(String(format: NSLocalizedString("about.version", comment: ""), appVersion))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Description
                VStack(spacing: 16) {
                    Text("about.tagline")
                        .font(.headline)
                    
                    Text("about.description")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Credits
                VStack(spacing: 8) {
                    Text("about.developedBy")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Jonas Halbe")
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                // Contact Button
                Button {
                    if let url = URL(string: "mailto:hello@halbe.no") {
                        UIApplication.shared.open(url) { success in
                            if !success {
                                showMailError = true
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: "envelope.fill")
                        Text("about.contactUs")
                    }
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
                .padding(.top, 8)
                
                // Legal Links
                VStack(spacing: 12) {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy Policy")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    NavigationLink {
                        TermsOfServiceView()
                    } label: {
                        Text("Terms of Service")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 16)
                
                // Copyright
                Text("© 2024 Jonas Halbe. All rights reserved.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("settings.about")
        .navigationBarTitleDisplayMode(.inline)
        .alert("about.emailError.title", isPresented: $showMailError) {
            Button("action.ok", role: .cancel) { }
        } message: {
            Text("about.emailError.message")
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}


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
                // App Icon (placeholder - you can replace with actual icon)
                Image(systemName: "film.stack")
                    .font(.system(size: 80))
                    .foregroundColor(.accentColor)
                    .padding(.top, 32)
                
                // App Name
                Text("FilmStock")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Version
                Text("Version \(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Description
                VStack(spacing: 16) {
                    Text("Your Personal Film Collection Manager")
                        .font(.headline)
                    
                    Text("FilmStock helps you keep track of your analog film collection, manage loaded films in your cameras, and never lose track of your favorite film stocks.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Divider()
                    .padding(.horizontal, 32)
                
                // Credits
                VStack(spacing: 8) {
                    Text("Developed by")
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
                        Text("Contact Us")
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
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Email Not Available", isPresented: $showMailError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please contact us at hello@halbe.no")
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


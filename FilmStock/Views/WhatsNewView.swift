//
//  WhatsNewView.swift
//  FilmStock
//
//  One-time "What's New" sheet shown after a major update.
//

import SwiftUI

// Bump this string whenever you want to show the sheet again on next launch.
let whatsNewVersion = "2.0"

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

struct WhatsNewView: View {
    @Binding var isPresented: Bool

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "film.stack",
            iconColor: .accentColor,
            title: "Roll-by-Roll Tracking",
            description: "Each roll is now its own record with an individual expiry date, frozen status, exposure count, and notes — no more shared batches. All your previously added film got migrated to the new system."
        ),
       
        WhatsNewFeature(
            icon: "plus.circle",
            iconColor: .green,
            title: "Flexible Roll Adding",
            description: "When adding a film you can create multiple roll batches at once — mix 35mm, 120, and sheet film in a single save."
        ),
        
        WhatsNewFeature(
            icon: "info.circle",
            iconColor: .blue,
            title: "Roll Detail Sheets",
            description: "Tap any loaded or finished roll to see a full detail sheet: load date, days on camera, shot ISO, exposures, frozen status, and more."
        ),
        WhatsNewFeature(
            icon: "magnifyingglass",
            iconColor: .pink,
            title: "Image Catalog Search",
            description: "The film image picker now has a live search that matches manufacturer names, film names, and all known aliases from the catalog."
        ),
        WhatsNewFeature(
            icon: "calendar.badge.exclamationmark",
            iconColor: .red,
            title: "Multiple Expiry Dates",
            description: "In case you have used multiple expiry dates for the same film, make sure to assign the right expiry date to the right roll."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.accentColor)
                            .padding(.top, 32)

                        Text("What's New")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Here's everything that changed in this update.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.bottom, 32)

                    // Feature list
                    VStack(spacing: 0) {
                        ForEach(features) { feature in
                            FeatureRow(feature: feature)
                            if feature.id != features.last?.id {
                                Divider().padding(.leading, 72)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)

                    Spacer(minLength: 32)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button {
                    isPresented = false
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .background(
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea(edges: .bottom)
                )
            }
            .navigationBarHidden(true)
        }
    }
}

private struct FeatureRow: View {
    let feature: WhatsNewFeature

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(feature.iconColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: feature.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(feature.iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 14)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

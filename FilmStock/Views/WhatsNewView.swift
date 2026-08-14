//
//  WhatsNewView.swift
//  FilmStock
//
//  One-time "What's New" sheet shown after a major update.
//

import SwiftUI

// Bump this string whenever you want to show the sheet again on next launch.
let whatsNewVersion = "2.4"

struct WhatsNewFeature: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    var showBeta: Bool = false
}

struct WhatsNewView: View {
    @Binding var isPresented: Bool

    private let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "barcode.viewfinder",
            iconColor: .accentColor,
            title: "Scan barcodes to add film",
            description: "On Add Film, scan a packaging barcode or the DX code on a 35mm canister to prefill the film and add rolls or sheets. For example, scan a new Portra 400 pro-pack to add 5 rolls at once. Packaging lookup covers 70+ films with more coming later. This feature is in beta, so results may not always be accurate.",
            showBeta: true
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
            .padding(.top, 14)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(feature.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    if feature.showBeta {
                        Text("BETA")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.orange, lineWidth: 1))
                    }
                }
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

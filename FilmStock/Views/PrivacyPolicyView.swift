//
//  PrivacyPolicyView.swift
//  FilmStock
//
//  Privacy Policy for the app
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("legal.privacyPolicy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("legal.lastUpdated")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Group {
                    SectionView(
                        title: "Introduction",
                        content: "FilmStock (\"we,\" \"our,\" or \"us\") is committed to protecting your privacy. This Privacy Policy explains how we handle information when you use our mobile application."
                    )
                    
                    SectionView(
                        title: "Data Collection",
                        content: "FilmStock does NOT collect, transmit, or share any personal information. All data you create in the app remains exclusively on your device."
                    )
                    
                    SectionView(
                        title: "Information Stored Locally",
                        content: """
                        The following information is stored locally on your device only:
                        • Film stock inventory and details
                        • Custom photos of film boxes you take with the camera
                        • App settings and preferences
                        • Films loaded in your cameras
                        
                        This data is never transmitted to our servers or any third parties.
                        """
                    )
                    
                    SectionView(
                        title: "Camera Access",
                        content: "FilmStock requests camera access only to allow you to take photos of your film boxes for visual reference. These photos are stored locally on your device and are never uploaded or shared."
                    )
                    
                    SectionView(
                        title: "In-App Purchases",
                        content: "FilmStock offers an optional in-app purchase (\"Buy Me a Coffee\") to support development. This transaction is processed securely by Apple through the App Store. We do not receive or store any payment information."
                    )
                }
                
                Group {
                    SectionView(
                        title: "Third-Party Services",
                        content: """
                        FilmStock uses the following Apple services:
                        • StoreKit for in-app purchases
                        • WidgetKit for home screen widgets
                        
                        These services are governed by Apple's Privacy Policy. We do not integrate any third-party analytics, advertising, or tracking services.
                        """
                    )
                    
                    SectionView(
                        title: "Data Sharing",
                        content: "We do not share, sell, rent, or trade your information with anyone. Since all data is stored locally on your device, there is no data to share."
                    )
                    
                    SectionView(
                        title: "Children's Privacy",
                        content: "FilmStock does not knowingly collect any information from children. The app is designed for general audiences and does not target children specifically."
                    )
                    
                    SectionView(
                        title: "Data Deletion",
                        content: "You can delete all app data at any time by deleting the FilmStock app from your device. This will permanently remove all locally stored information."
                    )
                    
                    SectionView(
                        title: "Changes to This Policy",
                        content: "We may update this Privacy Policy from time to time. Any changes will be reflected in the app with an updated \"Last updated\" date."
                    )
                    
                    SectionView(
                        title: "Contact Us",
                        content: "If you have any questions about this Privacy Policy, please contact us at hello@halbe.no"
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("legal.privacyPolicy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}


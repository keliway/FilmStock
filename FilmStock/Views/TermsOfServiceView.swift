//
//  TermsOfServiceView.swift
//  FilmStock
//
//  Terms of Service for the app
//

import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                Text("Last updated: November 2024")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Group {
                    TermsSectionView(
                        title: "1. Acceptance of Terms",
                        content: "By downloading, installing, or using FilmStock (\"the App\"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App."
                    )
                    
                    TermsSectionView(
                        title: "2. License to Use",
                        content: "FilmStock grants you a personal, non-exclusive, non-transferable, revocable license to use the App for your personal, non-commercial purposes, subject to these Terms."
                    )
                    
                    TermsSectionView(
                        title: "3. App Purpose",
                        content: "FilmStock is designed to help you manage your analog film stock inventory, track loaded films in your cameras, and organize your collection. The App is provided for informational and organizational purposes only."
                    )
                    
                    TermsSectionView(
                        title: "4. User Responsibilities",
                        content: """
                        You are responsible for:
                        • Maintaining the accuracy of information you enter
                        • Backing up your data (all data is stored locally)
                        • Ensuring the security of your device
                        • Using the camera feature responsibly and lawfully
                        """
                    )
                    
                    TermsSectionView(
                        title: "5. Data and Backups",
                        content: "All data is stored locally on your device. We do not provide cloud backup services. You are solely responsible for backing up your device to preserve your data. Loss of data due to device loss, damage, or app deletion is not our responsibility."
                    )
                }
                
                Group {
                    TermsSectionView(
                        title: "6. In-App Purchases",
                        content: """
                        FilmStock offers an optional in-app purchase (\"Buy Me a Coffee\") to support development:
                        • Purchases are processed through Apple's App Store
                        • Payments are non-refundable except as required by law
                        • Purchases do not unlock additional features
                        • Purchases support ongoing app development and maintenance
                        """
                    )
                    
                    TermsSectionView(
                        title: "7. Intellectual Property",
                        content: "The App, including its design, features, code, and content, is owned by Jonas Halbe and protected by copyright and other intellectual property laws. You may not copy, modify, distribute, or reverse engineer the App."
                    )
                    
                    TermsSectionView(
                        title: "8. Disclaimer of Warranties",
                        content: "THE APP IS PROVIDED \"AS IS\" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED. WE DO NOT WARRANT THAT THE APP WILL BE ERROR-FREE, UNINTERRUPTED, OR FREE FROM HARMFUL COMPONENTS."
                    )
                    
                    TermsSectionView(
                        title: "9. Limitation of Liability",
                        content: "TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, OR ANY LOSS OF PROFITS OR REVENUES, WHETHER INCURRED DIRECTLY OR INDIRECTLY, OR ANY LOSS OF DATA, USE, OR OTHER INTANGIBLE LOSSES."
                    )
                    
                    TermsSectionView(
                        title: "10. Updates and Changes",
                        content: "We may update, modify, or discontinue the App at any time without notice. We may also update these Terms from time to time. Continued use of the App after changes constitutes acceptance of the updated Terms."
                    )
                }
                
                Group {
                    TermsSectionView(
                        title: "11. Termination",
                        content: "You may stop using the App at any time by deleting it from your device. We reserve the right to terminate or restrict access to the App for any reason, including violation of these Terms."
                    )
                    
                    TermsSectionView(
                        title: "12. Governing Law",
                        content: "These Terms are governed by the laws of Norway, without regard to conflict of law principles."
                    )
                    
                    TermsSectionView(
                        title: "13. Contact Information",
                        content: "If you have questions about these Terms of Service, please contact us at hello@halbe.no"
                    )
                    
                    TermsSectionView(
                        title: "14. Entire Agreement",
                        content: "These Terms constitute the entire agreement between you and FilmStock regarding use of the App and supersede all prior agreements and understandings."
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TermsSectionView: View {
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
        TermsOfServiceView()
    }
}


//
//  SupportView.swift
//  FilmStock
//
//  Support the developer view with in-app purchase
//

import SwiftUI
import StoreKit
import Combine

struct SupportView: View {
    @StateObject private var storeManager = StoreManager()
    @State private var showConfirmation = false
    @State private var showThankYou = false
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    if #available(iOS 17.4, *) {
                        Image(systemName: "cup.and.heat.waves.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                            .padding(.top, 32)
                    } else {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                            .padding(.top, 32)
                    }
                    
                    // Title
                    Text("support.header")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    VStack(spacing: 16) {
                        Group {
                            if let product = storeManager.products.first {
                                Text(String(format: NSLocalizedString("support.message.withPrice", comment: ""), product.displayPrice))
                            } else {
                                Text("support.message")
                            }
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        
                        Text("support.benefits")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Spacer()
                        .frame(height: 20)
                    
                    // Support Button
                    Button {
                        if storeManager.products.first != nil {
                            showConfirmation = true
                        }
                    } label: {
                        HStack {
                            if #available(iOS 17.4, *) {
                                Image(systemName: "cup.and.heat.waves.fill")
                            } else {
                                Image(systemName: "heart.fill")
                            }
                            if let product = storeManager.products.first {
                                Text(String(format: NSLocalizedString("support.button.withPrice", comment: ""), product.displayPrice))
                                    .fontWeight(.semibold)
                            } else {
                                Text("support.buyMeCoffee")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(storeManager.products.isEmpty ? Color.gray : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 32)
                    .disabled(storeManager.isPurchasing || storeManager.products.isEmpty)
                    
                    if storeManager.products.isEmpty && !storeManager.isPurchasing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("support.loading")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    if storeManager.isPurchasing {
                        ProgressView()
                            .padding()
                    }
                    
                    if let error = storeManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Thank you message
                    if showThankYou {
                        VStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.pink)
                            Text("support.thankYou.title")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("support.thankYou.message")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal, 32)
                    }
                    
                    Spacer()
                }
                .padding()
        }
        .navigationTitle("support.title")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("support.confirm.title", isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("support.confirm", role: .none) {
                    storeManager.purchaseCoffee()
                }
                Button("action.cancel", role: .cancel) { }
            } message: {
                if let product = storeManager.products.first {
                    Text(String(format: NSLocalizedString("support.confirm.message", comment: ""), product.displayPrice))
                } else {
                    Text("support.confirm.message.noPrice")
                }
            }
        .onChange(of: storeManager.purchaseSuccessful) { oldValue, newValue in
            if newValue {
                showThankYou = true
            }
        }
        .onAppear {
            storeManager.loadProducts()
        }
    }
}

@MainActor
class StoreManager: ObservableObject {
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var purchaseSuccessful = false
    @Published var products: [Product] = []
    
    private let productID = "halbe.no.FilmStock.support.coffee"
    
    func loadProducts() {
        Task {
            do {
                let products = try await Product.products(for: [productID])
                await MainActor.run {
                    self.products = products
                }
            } catch {
                await MainActor.run {
                    print("Failed to load products: \(error)")
                }
            }
        }
    }
    
    func purchaseCoffee() {
        guard let product = products.first else {
            purchaseError = NSLocalizedString("support.error.productNotAvailable", comment: "")
            return
        }
        
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                let result = try await product.purchase()
                
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        await MainActor.run {
                            purchaseSuccessful = true
                            isPurchasing = false
                        }
                    case .unverified(_, let error):
                        await MainActor.run {
                            purchaseError = String(format: NSLocalizedString("support.error.verificationFailed", comment: ""), error.localizedDescription)
                            isPurchasing = false
                        }
                    }
                case .userCancelled:
                    await MainActor.run {
                        isPurchasing = false
                    }
                case .pending:
                    await MainActor.run {
                        purchaseError = NSLocalizedString("support.error.pending", comment: "")
                        isPurchasing = false
                    }
                @unknown default:
                    await MainActor.run {
                        purchaseError = NSLocalizedString("support.error.unknown", comment: "")
                        isPurchasing = false
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseError = String(format: NSLocalizedString("support.error.failed", comment: ""), error.localizedDescription)
                    isPurchasing = false
                }
            }
        }
    }
}


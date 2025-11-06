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
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeManager = StoreManager()
    @State private var showConfirmation = false
    @State private var showThankYou = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: "cup.and.heat.waves.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                        .padding(.top, 32)
                    
                    // Title
                    Text("Support FilmStock")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    VStack(spacing: 16) {
                        Group {
                            if let product = storeManager.products.first {
                                Text("If you're enjoying FilmStock, consider supporting its development with a small \(product.displayPrice) contribution.")
                            } else {
                                Text("If you're enjoying FilmStock, consider supporting its development with a small contribution.")
                            }
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        
                        Text("Your support helps keep the app updated, adds new features, and ensures FilmStock continues to be the best film management app.")
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
                            Image(systemName: "cup.and.heat.waves.fill")
                            if let product = storeManager.products.first {
                                Text("Buy Me a Coffee (\(product.displayPrice))")
                                    .fontWeight(.semibold)
                            } else {
                                Text("Buy Me a Coffee")
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
                            Text("Loading...")
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
                            Text("Thank You!")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Your support means the world to me. I truly appreciate it!")
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
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Confirm Support", isPresented: $showConfirmation, titleVisibility: .visible) {
                Button("Yes, Support FilmStock") {
                    storeManager.purchaseCoffee()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let product = storeManager.products.first {
                    Text("This will purchase a \(product.displayPrice) support contribution. Thank you for your generosity!")
                } else {
                    Text("This will purchase a support contribution. Thank you for your generosity!")
                }
            }
            .onChange(of: storeManager.purchaseSuccessful) { oldValue, newValue in
                if newValue {
                    showThankYou = true
                    // Auto-dismiss after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                storeManager.loadProducts()
            }
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
            purchaseError = "Product not available. Please try again later."
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
                            purchaseError = "Purchase verification failed: \(error.localizedDescription)"
                            isPurchasing = false
                        }
                    }
                case .userCancelled:
                    await MainActor.run {
                        isPurchasing = false
                    }
                case .pending:
                    await MainActor.run {
                        purchaseError = "Purchase is pending approval"
                        isPurchasing = false
                    }
                @unknown default:
                    await MainActor.run {
                        purchaseError = "Unknown purchase result"
                        isPurchasing = false
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseError = "Purchase failed: \(error.localizedDescription)"
                    isPurchasing = false
                }
            }
        }
    }
}


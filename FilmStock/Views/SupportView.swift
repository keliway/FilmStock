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
                    
                    // Restore Purchases Button
                    Button {
                        storeManager.restorePurchases()
                    } label: {
                        Text("support.restore")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 8)
                    .disabled(storeManager.isPurchasing)
                    
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
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        // Start listening for transaction updates
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any unfinished transactions
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    
                    // Deliver content or update UI
                    await MainActor.run {
                        self.purchaseSuccessful = true
                    }
                    
                    // Always finish the transaction
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content.
                }
            }
        }
    }
    
    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        // Check if the transaction passes StoreKit verification
        switch result {
        case .unverified:
            // StoreKit parses the JWS, but it fails verification
            throw StoreError.failedVerification
        case .verified(let safe):
            // The result is verified, return the unwrapped value
            return safe
        }
    }
    
    func loadProducts() {
        Task {
            do {
                let products = try await Product.products(for: [productID])
                await MainActor.run {
                    self.products = products
                }
            } catch {
                await MainActor.run {
                    self.purchaseError = NSLocalizedString("support.error.productNotAvailable", comment: "")
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
                    do {
                        let transaction = try checkVerified(verification)
                        await transaction.finish()
                        await MainActor.run {
                            purchaseSuccessful = true
                            isPurchasing = false
                        }
                    } catch {
                        await MainActor.run {
                            purchaseError = NSLocalizedString("support.error.verificationFailed", comment: "")
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
    
    func restorePurchases() {
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await AppStore.sync()
                
                // Check if user has purchased the coffee
                for await result in Transaction.currentEntitlements {
                    do {
                        let transaction = try checkVerified(result)
                        
                        if transaction.productID == productID {
                            await MainActor.run {
                                purchaseSuccessful = true
                                isPurchasing = false
                            }
                            return
                        }
                    } catch {
                        // Failed verification, skip this transaction
                        continue
                    }
                }
                
                // No purchases found
                await MainActor.run {
                    purchaseError = NSLocalizedString("support.error.nothingToRestore", comment: "")
                    isPurchasing = false
                }
            } catch {
                await MainActor.run {
                    purchaseError = String(format: NSLocalizedString("support.error.restoreFailed", comment: ""), error.localizedDescription)
                    isPurchasing = false
                }
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

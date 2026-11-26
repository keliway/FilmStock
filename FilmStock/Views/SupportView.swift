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
    static var iconSystemName: String {
        if #available(iOS 17.4, *) {
            return "cup.and.heat.waves.fill"
        } else {
            return "heart.fill"
        }
    }

    @StateObject private var storeManager = StoreManager()
    @State private var showConfirmation = false
    @State private var showThankYou = false
    
    var body: some View {
        ScrollView {
                VStack(spacing: 24) {
                    // Icon
                    Image(systemName: Self.iconSystemName)
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                        .padding(.top, 32)
                    
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
                            Image(systemName: Self.iconSystemName)
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
                    
                    if storeManager.isLoadingProducts && !storeManager.isPurchasing {
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
    @Published var isLoadingProducts = false
    @Published var isPurchasing = false
    @Published var purchaseError: String?
    @Published var purchaseSuccessful = false
    @Published var products: [Product] = []
    
    private let productID = "halbe.no.FilmStock.support.coffee"
    private var updateListenerTask: Task<Void, Never>?
    
    init() {
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                do {
                    let transaction = try Self.checkVerified(result)
                    await MainActor.run {
                        self?.purchaseSuccessful = true
                    }
                    await transaction.finish()
                } catch {
                    // StoreKit has a transaction that fails verification. Don't deliver content.
                }
            }
        }
    }
    
    nonisolated private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    func loadProducts() {
        guard !isLoadingProducts, products.isEmpty else { return }
        isLoadingProducts = true
        purchaseError = nil
        Task {
            do {
                let fetched = try await Product.products(for: [productID])
                self.products = fetched
                if fetched.isEmpty {
                    self.purchaseError = NSLocalizedString("support.error.productNotAvailable", comment: "")
                }
            } catch {
                self.purchaseError = NSLocalizedString("support.error.productNotAvailable", comment: "")
            }
            self.isLoadingProducts = false
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
                        let transaction = try Self.checkVerified(verification)
                        await transaction.finish()
                        purchaseSuccessful = true
                        isPurchasing = false
                    } catch {
                        purchaseError = NSLocalizedString("support.error.verificationFailed", comment: "")
                        isPurchasing = false
                    }
                case .userCancelled:
                    isPurchasing = false
                case .pending:
                    purchaseError = NSLocalizedString("support.error.pending", comment: "")
                    isPurchasing = false
                @unknown default:
                    purchaseError = NSLocalizedString("support.error.unknown", comment: "")
                    isPurchasing = false
                }
            } catch {
                purchaseError = String(format: NSLocalizedString("support.error.failed", comment: ""), error.localizedDescription)
                isPurchasing = false
            }
        }
    }
    
    func restorePurchases() {
        isPurchasing = true
        purchaseError = nil
        
        Task {
            do {
                try await AppStore.sync()
                
                for await result in Transaction.currentEntitlements {
                    do {
                        let transaction = try Self.checkVerified(result)
                        if transaction.productID == productID {
                            purchaseSuccessful = true
                            isPurchasing = false
                            return
                        }
                    } catch {
                        continue
                    }
                }
                
                purchaseError = NSLocalizedString("support.error.nothingToRestore", comment: "")
                isPurchasing = false
            } catch {
                purchaseError = String(format: NSLocalizedString("support.error.restoreFailed", comment: ""), error.localizedDescription)
                isPurchasing = false
            }
        }
    }
}

enum StoreError: Error {
    case failedVerification
}

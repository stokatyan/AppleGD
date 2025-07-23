//
//  InAppPurchaseNode.swift
//  AppleGD
//
//  Created by Shant Tokatyan on 7/19/25.
//

import SwiftGodot
import StoreKit

@Godot
class StoreKitNode: Node {
    
    private let kPendingPurchaseSet = "kPendingPurchaseSet"
    
    @MainActor
    private var idToProductMap = [String: Product]()
    
    /**
     A signal that emits when a product purchase is completed.
     - parameters:
        - product: The id of the product that was successfuly purchased.
        - verificationResult: `true` iff StoreKit was able to verify the purchase.
     */
    @Signal var didCompleteProductPurchase: SignalWithArguments<String, Bool>
    
    /**
     A signal that emits when a product purchase is canceled.
     - parameters:
        - product: The id of the product purchase that was canceled.
     */
    @Signal var didCancelProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a prodcut purchase is pending, which may result in a future signal regarding the state of the purchase.
     - parameters:
        - product: The id of the product that is pending.
     */
    @Signal var didCreatePendingProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a product purchase failed.
     */
    @Signal var didFailToCompleteProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when a product purchase reaches an unkown state.
     */
    @Signal var didReachUnkownStateInProductPurchase: SignalWithArguments<String>
    
    /**
     A signal that emits when products fail to load.
     - parameters:
        - products: The array of productIds that failed to load.
     */
    @Signal var didFailToLoadAppProducts: SignalWithArguments<[String]>
    
    /**
     A signal that emits when products are loaded.
     - parameters:
        - products: A variant that holds an array of dictionaries representing the product.
     */
    @Signal var didLoadAppProducts: SignalWithArguments<VariantArray>
    
    @Callable(autoSnakeCase: true)
    func listenForTransactionUpdates() {
        let didCompletePurchase = didCompleteProductPurchase
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try result.payloadValue
                    let productId = transaction.productID
                    if transaction.revocationDate == nil {
                        didCompletePurchase.emit(productId, true)
                    }
                    
                    setIsPurchasePending(id: productId, isPending: false)
                    await transaction.finish()
                    print("Transaction update received:", transaction)
                } catch {
                    print("Transaction update failed:", error)
                }
            }
        }
    }
        
    @Callable(autoSnakeCase: true)
    func requestProducts(productIdentifiers: [String]) {
        let successSignal = didLoadAppProducts
        let failureSignal = didFailToLoadAppProducts
        Task { @MainActor in
            await self.requestProducts(productIdentifiers: productIdentifiers)
            

            var gProducts = VariantArray()
            var failedToLoadProducts = [String]()
            
            for productIdentifier in productIdentifiers {
                if let product = idToProductMap[productIdentifier] {
                    print("Swift (requestProducts): succeeded to load product for id \(productIdentifier)")
                    let gProduct = GProduct()
                    await gProduct.set(product: product)
                    gProducts.append(gProduct.toVariant())
                } else {
                    print("Swift (requestProducts): failed to load product for id \(productIdentifier)")
                    failedToLoadProducts.append(productIdentifier)
                }
            }
            
            successSignal.emit(gProducts)
            if !failedToLoadProducts.isEmpty {
                failureSignal.emit(failedToLoadProducts)
            }
        }
    }
    
    @MainActor
    private func requestProducts(productIdentifiers: [String]) async {
        let failureSignal = didFailToLoadAppProducts
        do {
            let appProducts = try await Product.products(for: productIdentifiers)
            for product in appProducts {
                idToProductMap[product.id] = product
                print("Swift (requestProducts): did fetch \(product.id)")
            }
        } catch {
            print("Swift (requestProducts): Fail to load product identifiers")
            print("  error:\n\(error)")
            failureSignal.emit(productIdentifiers)
        }
    }
    
    @Callable(autoSnakeCase: true)
    func purchaseProduct(productId: String) {
        let didCancelPurchase = didCancelProductPurchase
        let didCompletePurchase = didCompleteProductPurchase
        let didCreatePendingPurchase = didCreatePendingProductPurchase
        let didFailToCompletePurchase = didFailToCompleteProductPurchase
        let didReachUnkownState = didReachUnkownStateInProductPurchase
        
        Task { @MainActor in
            if idToProductMap[productId] == nil {
                print("Swift (purchaseProduct): fetching \(productId)")
                await requestProducts(productIdentifiers: [productId])
            }
            
            guard let product = idToProductMap[productId] else {
                print("Swift (purchaseProduct): Failed to find product")
                return
            }
            
            Task {
                do {
                    let result = await try product.purchase()
                    switch result {
                    case .success(let verificationResult):
                        switch verificationResult {
                        case .unverified:
                            didCompletePurchase.emit(productId, false)
                            print("Swift (purchaseProduct): unverified")
                        case .verified:
                            print("Swift (purchaseProduct): verified, but will be handled in listenForTransactionUpdates")
                        }
                    case .userCancelled:
                        didCancelProductPurchase.emit(productId)
                        print("Swift: purchaseProduct (userCancelled)")
                    case .pending:
                        setIsPurchasePending(id: productId, isPending: true)
                        didCreatePendingPurchase.emit(productId)
                        print("Swift: purchaseProduct (pending)")
                    @unknown default:
                        didReachUnkownState.emit(productId)
                        print("Swift: purchaseProduct (unkown)")
                    }
                } catch {
                    didFailToCompletePurchase.emit(productId)
                    print("Swift: purchaseProduct (error): \(error)")
                }
            }
        }
    }
    
    @Callable(autoSnakeCase: true)
    func requestReview() {
        #if os(iOS)
        Task { @MainActor in
            guard let window = ViewControllerPresenter.activeWindowScene else {
                print("StoreKitNode: Failed to Request Review, no window")
                return
            }
            AppStore.requestReview(in: window)
            print("StoreKitNode: requestReview completed")
        }
        #else
        print("StoreKitNode: Failed to Request Review, not iOS")
        #endif
    }
    
    private func getIsPurchasePending(id: String) -> Bool {
        let array = UserDefaults.standard.stringArray(forKey: kPendingPurchaseSet) ?? []
        return array.contains { $0 == id }
    }
    
    private func setIsPurchasePending(id: String, isPending: Bool) {
        let array = UserDefaults.standard.stringArray(forKey: kPendingPurchaseSet) ?? []
        var set = Set(array)
        if isPending {
            set.insert(id)
        } else {
            set.remove(id)
        }
        
        let updatedArray = Array(set)
        UserDefaults.standard.set(set, forKey: kPendingPurchaseSet)
    }
}

extension StoreKitNode: @unchecked Sendable {}

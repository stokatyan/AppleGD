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
    
    var products = [String: Product]()
    
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
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try result.payloadValue
                    let productId = transaction.productID
                
                    if getIsPurchasePending(id: productId), transaction.revocationDate == nil {
                        setIsPurchasePending(id: productId, isPending: false)
                        print("Swift (listenForTransactionUpdates): Did complete pending transaction")
                        
                        Task { @MainActor in
                            self.didCompletePurchase(productId: productId)
                            await transaction.finish()
                        }
                    } else {
                        await transaction.finish()
                    }
                    print("Swift (listenForTransactionUpdates): \n  Did finish transaction: \(transaction.productID)")
                } catch {
                    print("Swift (listenForTransactionUpdates): \(error)")
                }
            }
        }
        
        Task {
            for await result in Transaction.unfinished {
                switch result {
                case .verified(let transaction):
                    print("Finishing unhandled transaction: \(transaction.productID)")
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    print("Unverified transaction: \(transaction.productID), error: \(error.localizedDescription)")
                    await transaction.finish()
                }
            }
        }
    }
    
    @MainActor
    private func didCompletePurchase(productId: String) {
        didCompleteProductPurchase.emit(productId, true)
    }
        
    @MainActor
    private func requestProducts(productIdentifiers: [String]) async -> [String: Product] {
        var result = [String: Product]()
        do {
            let appProducts = try await Product.products(for: productIdentifiers)
            for product in appProducts {
                result[product.id] = product
                print("Swift (requestProducts) did load: \(product.id)")
            }
        } catch {
            print("Swift (requestProducts) error: \(error)")
            return result
        }
        
        return result
    }
    
    @Callable(autoSnakeCase: true)
    func purchaseProduct(productId: String) {
        let didCancelPurchase = didCancelProductPurchase
        let didCompletePurchase = didCompleteProductPurchase
        let didCreatePendingPurchase = didCreatePendingProductPurchase
        let didFailToCompletePurchase = didFailToCompleteProductPurchase
        let didReachUnkownState = didReachUnkownStateInProductPurchase
        
        Task { @MainActor in
            let idToProductMap = await requestProducts(productIdentifiers: [productId])
            
            guard let product = idToProductMap[productId] else {
                print("Swift (purchaseProduct): Failed to find product")
                didFailToCompletePurchase.emit(productId)
                return
            }
            
            do {
                let result = await try product.purchase()
                switch result {
                case .success(let verificationResult):
                    switch verificationResult {
                    case .unverified:
                        didCompletePurchase.emit(productId, false)
                        print("Swift (purchaseProduct): unverified")
                    case .verified(let transaction):
                        didCompletePurchase.emit(productId, true)
                        print(transaction)
                        do {
                            try await transaction.finish()
                            listenForTransactionUpdates()
                        }
                        catch {
                            print("Swift (purchaseProduct) error: \(error)")
                        }
                        
                        print("Swift (purchaseProduct): finished")
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
